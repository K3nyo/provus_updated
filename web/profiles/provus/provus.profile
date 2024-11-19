<?php

use \Drupal\Core\Entity\RevisionLogInterface;

/**
 * @file
 * Contains provus.profile.
 */

use Drupal\Core\Session\AccountInterface;
use Drupal\provus\Installer\Form\ProvusConfigureForm;
use Drupal\provus\Installer\Form\ProvusDemoForm;
use Symfony\Component\Yaml\Parser;

/**
 * Implements hook_install_tasks().
 */
function provus_install_tasks() {
  return [
    'provus_install_extensions' => [
      'display_name' => t('Install Provus Extensions'),
      'display' => TRUE,
      'type' => 'batch',
    ],
    'provus_install_demo_content' => [
      'display_name' => t('Install Demo Content'),
      'display' => TRUE,
      'type' => 'batch',
    ],
  ];
}


/**
 * Implements hook_install_tasks_alter().
 */
function provus_install_tasks_alter(array &$tasks, array $install_state) {
  $task_keys = array_keys($tasks);
  $insert_before = array_search('provus_install_extensions', $task_keys, TRUE);
  $tasks = array_slice($tasks, 0, $insert_before - 1, TRUE) +
    [
      'provus_extension_configure_form' => [
        'display_name' => t('Configure Provus'),
        'type' => 'form',
        'function' => ProvusConfigureForm::class,
      ],
    ] +
    array_slice($tasks, $insert_before - 1, NULL, TRUE);
}

/**
 * Install task callback prepares a batch job to install Provus extensions.
 *
 * @param array $install_state
 *   The current install state.
 *
 * @return array
 *   The batch job definition.
 */
function provus_install_extensions(array &$install_state) {
  $batch = [];
  $modules = \Drupal::state()->get('provus_install_extensions', []);
  $install_core_search = TRUE;

  foreach ($modules as $module) {
    $batch['operations'][] = ['provus_install_module', (array) $module];
    if ($module == 'provus_ext_search_db') {
      $install_core_search = FALSE;
    }
  }
  // No need to install search & grant permission related to search.
  // if ($install_core_search) {
  //   $batch['operations'][] = ['provus_install_module', (array) 'search'];
  //   // Enable default permissions for system roles.
  //   user_role_grant_permissions(AccountInterface::ANONYMOUS_ROLE, [
  //     'search content',
  //   ]);
  // }

  return $batch;
}

/**
 * Install task callback prepares a batch job to install Provus demo content.
 *
 * @param array $install_state
 *   The current install state.
 *
 * @return array
 *   The batch job definition.
 */
function provus_install_demo_content(array &$install_state) {
  $modules = \Drupal::state()->get('provus_install_extensions', []);
  $demoName = \Drupal::state()->get('provus_demo_content');
  if (!$demoName || count($modules) < 9) {
    return; // Skip demo content. We need to enable all modules
  }

  if ($demoName == 'default') {
    // Run importer.
    $importer = \Drupal::service('default_content_deploy.importer');
    $importer->setForceOverride(TRUE);
    $importer->setFolder('profiles/provus/config/content/' . $demoName);
    $importer->prepareForImport();
    $importer->import();

    // Set homepage.
    $path = \Drupal::service('path_alias.manager')->getPathByAlias('/homepage');
    Drupal::configFactory()
      ->getEditable('system.site')
      ->set('page.front', $path)
      ->save(TRUE);

    // Get nid of homepage and exclude node title.
    list($nothing, $nothing, $nid) = explode('/', $path);
    $excludeNodeTitle = [$nid];

    $content = [
      '/404' => [
        'alias' => '/404',
        'exclude_node_title' => true,
      ],
    ];

    // Ensure that node 13 exists before setting the alias for /404
    $node_404 = \Drupal\node\Entity\Node::load(13);

    if ($node_404) {
      // Create the alias for /404 and set it to node/13
      $path_alias_manager = \Drupal::service('path_alias.manager');
      $path_alias_manager->save([
        'alias' => '/404', // This will be the alias
        'source' => 'node/13', // The node it points to
      ]);

      // Set the 404 page to /404 in system.site config
      Drupal::configFactory()
        ->getEditable('system.site')
        ->set('page.404', '/404') // Set the custom 404 page to the /404 alias
        ->save(TRUE);

      // Ensure that node 13 has a proper path alias
      $node_404->set('path', ['alias' => '/404', 'pathauto' => FALSE]);
      $node_404->save();
    }

    foreach ($content as $pattern => $item) {
      $path = \Drupal::service('path_alias.manager')->getPathByAlias($pattern);

      if (preg_match('/node\/(\d+)/', $path, $matches)) {
        $entity = \Drupal\node\Entity\Node::load($matches[1]);
        $entity->path = [
          'alias' => $item['alias'],
          'pathauto' => 0,
        ];
        $entity->save();

        if ($item['exclude_node_title']) {
          $excludeNodeTitle[] = $matches[1];
        }
      }
    }

    Drupal::configFactory()
      ->getEditable('exclude_node_title.settings')
      ->set('nid_list', $excludeNodeTitle)
      ->save(TRUE);

    // Set the homepage landing page to published.
    $node = \Drupal::entityTypeManager()->getStorage('node')->load($nid);
    $node->set('moderation_state', 'published');
    if ($node instanceof RevisionLogInterface) {
      $node->setRevisionLogMessage('Changed moderation state to Published.');
    }
    $node->save();
  }

  return [];
}

/**
 * Batch API callback. Installs a module.
 *
 * @param string|array $module
 *   The name(s) of the module(s) to install.
 */
function provus_install_module($module) {
  $module = (array) $module;
  \Drupal::service('module_installer')->install($module);
}

/**
 * Set the path to the logo, favicon and README file based on install directory.
 */
function provus_set_logo() {
  $provus_path = drupal_get_path('profile', 'provus');
  
  Drupal::configFactory()
    ->getEditable('system.theme.global')
    ->set('logo', [
    'path' => $provus_path . '/provus.svg',
    'url' => '',
    'use_default' => FALSE,
    ])
    ->set('favicon', [
    'mimetype' => 'image/vnd.microsoft.icon',
    'path' => $provus_path . '/favicon.ico',
    'url' => '',
    'use_default' => FALSE,
    ])
    ->save(TRUE);
}
  
