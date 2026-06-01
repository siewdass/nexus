class ModelOption {
  final String name;
  final String filename;
  final String url;

  const ModelOption({
    required this.name,
    required this.filename,
    required this.url,
  });
}

const availableModels = [
  ModelOption(
    name: 'Qwen 3 0.6B Q4',
    filename: 'Qwen3-0.6B-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf',
  ),
  ModelOption(
    name: 'Gemma 4 E2B Q4',
    filename: 'gemma-4-E2B-it-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf',
  ),
];
