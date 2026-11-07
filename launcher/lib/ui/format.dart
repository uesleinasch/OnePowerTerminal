String formatMb(int mb) {
  if (mb < 1000) return '$mb MB';
  return '${(mb / 1000).toStringAsFixed(1).replaceAll('.', ',')} GB';
}

const categoryOrder = ['base', 'shell', 'editor', 'terminal', 'dev', 'extras'];

const categoryTitles = {
  'base': 'Base do sistema',
  'shell': 'Shell e aparência',
  'editor': 'Editores',
  'terminal': 'Terminal',
  'dev': 'Ferramentas de desenvolvimento',
  'extras': 'Extras',
};

const categoryNotes = {
  'base': 'Pré-requisitos dos outros módulos',
  'editor': 'Escolha o Neovim, o VS Code ou os dois',
  'extras': 'Só no perfil full',
};

const profileSubtitles = {
  'todos': 'O catálogo inteiro. Escolha um perfil para ver um conjunto pronto.',
  'minimal': 'Só o shell: pacotes base, fontes, zsh e cheatsheets.',
  'dev': 'Ambiente completo de desenvolvimento. O editor você escolhe na hora de instalar.',
  'full': 'Tudo do dev, mais os extras e os dois editores.',
};
