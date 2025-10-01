# ================================================
# home/modules/nvim.nix
# -----------------------------------------------
# Komplett Neovim-oppsett (v2025)
# 🌸 Catppuccin | 🌳 Treesitter | 🧠 LSP | 💅 Format-on-save
# 🧩 AutoPairs + AutoTag | 🔢 nvim-cmp | 🪶 LuaSnip
# 🧭 Aerial (Symbols Sidebar) + Lualine Breadcrumbs
# 🖼️ nvim-web-devicons (ikoner)
# ================================================
{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    # --------------------------------------------------
    # 📦 Plugins
    # --------------------------------------------------
    plugins = with pkgs.vimPlugins; [
      # 🌳 Syntax parsing / highlight
      nvim-treesitter.withAllGrammars

      # 🧩 AutoPairs + AutoTag
      nvim-autopairs
      nvim-ts-autotag

      # 🌸 Tema + Statuslinje + Symbols + Ikoner
      catppuccin-nvim
      lualine-nvim
      aerial-nvim # 🧭 Symbols Sidebar (Outline)
      nvim-web-devicons # 🖼️ Ikoner (bruk Nerd Font i terminalen)

      # 🧠 Completion & Snippets
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      luasnip
      cmp_luasnip
      friendly-snippets

      # 🧠 LSP-konfig
      nvim-lspconfig

      # ➕ Utility
      emmet-vim
      vim-surround
    ];

    # --------------------------------------------------
    # ⚙️ Konfigurasjon (Lua)
    # --------------------------------------------------
    extraLuaConfig = ''
      ------------------------------------------------------------
      -- 🗂️ Filtype-mapping for React (JSX/TSX)
      ------------------------------------------------------------
      vim.filetype.add({
        extension = { jsx = "javascriptreact", tsx = "typescriptreact" },
      })

      ------------------------------------------------------------
      -- 🌸 Tema og UI
      ------------------------------------------------------------
      vim.opt.termguicolors = true
      vim.opt.number = true
      vim.opt.relativenumber = true

      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = false,
        integrations = {
          treesitter = true,
          native_lsp = { enabled = true },
          aerial = true,  -- 🧭 Aerial fargetema
          lsp_trouble = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")

      ------------------------------------------------------------
      -- 🖼️ Devicons (ikoner)
      --  Bruk en Nerd Font i terminalen (f.eks. JetBrainsMono Nerd Font).
      ------------------------------------------------------------
      local ok_icons, devicons = pcall(require, "nvim-web-devicons")
      if ok_icons then
        devicons.setup({})  -- standard mappinger
      end

      ------------------------------------------------------------
      -- 🌳 Treesitter
      ------------------------------------------------------------
      require("nvim-treesitter.install").prefer_git = false
      require("nvim-treesitter.configs").setup({
        highlight     = { enable = true },
        indent        = { enable = true },
        autotag       = { enable = true },
        auto_install  = false,
      })

      ------------------------------------------------------------
      -- 🧭 Aerial (Symbols Sidebar) med ikoner
      ------------------------------------------------------------
      require("aerial").setup({
        backends = { "lsp", "treesitter", "markdown" },
        layout = {
          default_direction = "right",
          max_width = { 40, 0.25 },
          min_width = 30,
        },
        show_guides = true,
        highlight_on_hover = true,
        manage_folds = false,
        -- Ikoner på
        icons = {},                  -- bruker devicons + interne symbolikoner
        nerd_font = "auto",          -- prøv å oppdage Nerd Font
      })

      -- Toggle med <leader>o
      vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle! right<CR>", { desc = "Toggle Aerial Outline" })

      -- (valgfritt) auto-åpne når LSP attacher
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function()
          local ok, aerial = pcall(require, "aerial")
          if ok then aerial.open({ focus = false }) end
        end,
      })

      ------------------------------------------------------------
      -- 💡 Lualine + Aerial Breadcrumbs + ikoner
      ------------------------------------------------------------
      local ok_aerial, aerial = pcall(require, "aerial")
      if package.loaded["lualine"] then
        require("lualine").setup({
          options = {
            theme = "catppuccin",
            icons_enabled = true,    -- ← vis ikoner i lualine
          },
          sections = {
            lualine_a = { "mode" },
            lualine_b = { "branch", "diff" },
            lualine_c = {
              { "filename", symbols = { modified = "", readonly = "", unnamed = "[No Name]" } },
              { function() return ok_aerial and aerial.get_location() or "" end,
                cond = function() return ok_aerial and aerial.is_available() end },
            },
            lualine_x = { "encoding", "filetype" },
            lualine_y = { "progress" },
            lualine_z = { "location" },
          },
        })
      end

      ------------------------------------------------------------
      -- 🧩 AutoPairs + nvim-cmp integrasjon
      ------------------------------------------------------------
      local autopairs = require("nvim-autopairs")
      autopairs.setup({})
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

      ------------------------------------------------------------
      -- 🧠 nvim-cmp (Autocompletion)
      ------------------------------------------------------------
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      require("luasnip.loaders.from_lua").lazy_load({ paths = "~/.config/nvim/snippets" })

      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"]      = cmp.mapping.confirm({ select = true }),
          ["<Tab>"]     = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"]   = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources(
          { { name = "nvim_lsp" }, { name = "luasnip" } },
          { { name = "buffer" }, { name = "path" } }
        )
      })

      ------------------------------------------------------------
      -- 🧠 LSP-konfig (Lua, TS, Nix) + Format on Save
      ------------------------------------------------------------
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Lua
      require("lspconfig").lua_ls.setup({ capabilities = capabilities })

      -- TypeScript / JavaScript
      local function ts_organize_imports(bufnr)
        local params = {
          command = "_typescript.organizeImports",
          arguments = { vim.api.nvim_buf_get_name(bufnr) },
          title = "",
        }
        pcall(vim.lsp.buf.execute_command, params)
      end

      require("lspconfig").ts_ls.setup({
        capabilities = capabilities,
        settings = {
          typescript = { format = { enable = false } },
          javascript = { format = { enable = false } },
        },
        on_attach = function(client, bufnr)
          local group = vim.api.nvim_create_augroup("TSFormatImports", { clear = true })
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = group,
            buffer = bufnr,
            callback = function()
              ts_organize_imports(bufnr)
              vim.lsp.buf.format({ async = false })
            end,
          })
        end,
      })

      -- Nix
      require("lspconfig").nixd.setup({
        capabilities = capabilities,
        on_attach = function(_, bufnr)
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function() vim.lsp.buf.format({ async = false }) end,
          })
        end,
      })
    '';
  };
}
