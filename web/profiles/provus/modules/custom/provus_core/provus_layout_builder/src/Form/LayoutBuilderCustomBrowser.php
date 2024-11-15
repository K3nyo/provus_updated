<?php

namespace Drupal\provus_layout_builder\Form;

use Drupal\Core\Ajax\AjaxResponse;
use Drupal\Core\Ajax\HtmlCommand;
use Drupal\Core\Form\ConfigFormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Entity\EntityFieldManagerInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Configuration for LayoutBuilder Browser Custom image.
 */
class LayoutBuilderCustomBrowser extends ConfigFormBase {


  /**
   * The entity type manager service.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected $entityTypeManager;


  /**
   * The entity type manager service.
   *
   * @var \Drupal\Core\Entity\EntityFieldManagerInterface
   */
  protected $entityFieldManager;


  /**
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  public function __construct(EntityTypeManagerInterface $entityTypeManager, EntityFieldManagerInterface $entityFieldManager) {
    $this->entityTypeManager = $entityTypeManager;
    $this->entityFieldManager = $entityFieldManager;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('entity_type.manager'),
      $container->get('entity_field.manager'),
    );
  }

  /**
   * {@inheritdoc}
   */
  protected function getEditableConfigNames() {
    return ['provus_layout_builder.browser.config'];
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'provus_layout_builder_browser';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $block_types_config = $this->config('provus_layout_builder.browser.config')
      ->get('radio_fields');
    $block_types = $this->entityTypeManager
      ->getStorage('block_content_type')
      ->getQuery()->execute();
    $options_fields = [];
    $options_block_type = [0 => '-- Select Block Type --'];

    foreach ($block_types as $block_type) {
      $options_block_type[$block_type] = $this->entityTypeManager
        ->getStorage('block_content_type')
        ->load($block_type)
        ->label();
      $fields =  $this->entityFieldManager
        ->getFieldDefinitions('block_content', $block_type);

      foreach ($fields as $machine_name => $field) {
        if (str_contains($machine_name, 'field_')) {
          $options_fields[$block_type][$machine_name] = $field->label();
        }
      }
    }

    $form['block_types'] = [
      '#type' => 'container',
      '#tree' => TRUE,
      '#attributes' => [
        'id' => 'block_types',
      ],
    ];
    // Override values form ajax.
    $ajax_response_option_values = $form_state->getValues();
    if (!empty($ajax_response_option_values['block_types'])) {
      $block_types_config = [];
      foreach ($ajax_response_option_values['block_types'] as $ajax_value) {
        $block_types_config[$ajax_value['id']] = $ajax_value['field'];
      }
    }

    $count = 0;
    foreach ($block_types_config as $key => $block_type_field) {
      $form['block_types'][$count] = [
        '#type' => 'details',
        '#title' => $this->t('#@count Block Type', [
          '@count' => $count + 1
        ]),
        '#open' => TRUE,
        '#attributes' => []
      ];

      // Select Lists.
      $form['block_types'][$count]['id'] = [
        '#type' => 'select',
        '#options' => $options_block_type,
        '#ajax' => [
          'callback' => '::blockTypeSelectedAjax',
          'event' => 'change',
          'wrapper' => 'block_types'
        ],
        '#default_value' => $key
      ];

      // Checkboxes.
      $form['block_types'][$count]['field'] = [
        '#type' => 'checkboxes',
        '#options' => $options_fields[$key] ? $options_fields[$key] : [],
        '#title' => $this->t('Choose field'),
        '#default_value' => $block_type_field ? $block_type_field : []
      ];

      // Remove button.
      $form['block_types'][$count]['action'] = [
        '#type' => 'submit',
        '#value' => $this->t('Remove'),
        '#name' => 'btn-' . $count,
        '#submit' => ['::removeItem'],
        '#ajax' => [
          'callback' => '::blockTypeSelectedAjax',
          'wrapper' => 'block_types',
        ]
      ];

      $count++;
    }

    $form['op']['add_item'] = [
      '#type' => 'submit',
      '#value' => $this->t('Add'),
      '#submit' => ['::addMoreItem'],
      '#ajax' => [
        'callback' => '::blockTypeSelectedAjax',
        'wrapper' => 'block_types',
      ]
    ];

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function removeItem($form, FormStateInterface &$form_state) {
    $ajax_values = $form_state->getValues();
    $index_item = $form_state->getUserInput()['_triggering_element_name'];
    $index_item = (int)str_replace('btn-', '', $index_item);

    unset($ajax_values['block_types'][$index_item]);
    $ajax_values['block_types'] = array_values($ajax_values['block_types']);

    $form_state->setValue('block_types', $ajax_values['block_types']);
    $form_state->setRebuild(TRUE);
    return $form_state;
  }

  /**
   * {@inheritdoc}
   */
  public function addMoreItem($form, FormStateInterface &$form_state) {
    $ajax_values = $form_state->getValues();
    $ajax_values['block_types'][] = [
      'id' => 0,
      'field' => [0 => FALSE]
    ];
    $form_state->setValue('block_types', $ajax_values['block_types']);
    $form_state->setRebuild(TRUE);
    return $form_state;
  }


  /**
   * {@inheritdoc}
   */
  public function blockTypeSelectedAjax($form, FormStateInterface $form_state) {
    return $form['block_types'];
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    $values = [];
    $block_types = $form_state->getValue('block_types');
    foreach ($block_types as $id => $block_type) {
      $values[$block_type['id']] = array_filter(array_values($block_type['field']));
    }
    $this->config('provus_layout_builder.browser.config')
      ->set('radio_fields', $values)->save();
    return parent::submitForm($form, $form_state);
  }

}
