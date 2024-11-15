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
  if ($install_core_search) {
    $batch['operations'][] = ['provus_install_module', (array) 'search'];
    // Enable default permissions for system roles.
    user_role_grant_permissions(AccountInterface::ANONYMOUS_ROLE, [
      'search content',
    ]);
  }

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
    $nids = [$nid];
    $content = [
      '/404' => [
        'exclude_node_title' => true
      ],
    ]
    Drupal::configFactory()
      ->getEditable('exclude_node_title.settings')
      ->set('nid_list', $nids)
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
  