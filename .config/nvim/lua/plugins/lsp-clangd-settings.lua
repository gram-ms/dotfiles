return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        on_attach = function(client, bufnr)
          vim.b[bufnr].autoformat = false
        end,
      },
    },
  },
}
