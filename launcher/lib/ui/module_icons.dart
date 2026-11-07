import 'package:flutter/material.dart';

IconData moduleIcon(String id) => switch (id) {
  'apt' => Icons.inventory_2_rounded,
  'fonts' => Icons.font_download_rounded,
  'zsh' => Icons.terminal_rounded,
  'helpers' => Icons.menu_book_rounded,
  'theme' => Icons.palette_rounded,
  'nvim' => Icons.edit_note_rounded,
  'astronvim' => Icons.tune_rounded,
  'vscode' => Icons.code_rounded,
  'kitty' => Icons.pets_rounded,
  'tools' => Icons.construction_rounded,
  'node' => Icons.data_object_rounded,
  'claude' => Icons.smart_toy_rounded,
  'container' => Icons.view_in_ar_rounded,
  'extras' => Icons.widgets_rounded,
  'notiont' => Icons.sticky_note_2_rounded,
  _ => Icons.extension_rounded,
};
