{pkgs, ...}: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    extensions = with pkgs.vscode-extensions; [
      esbenp.prettier-vscode
      dbaeumer.vscode-eslint
      dsznajder.es7-react-js-snippets
      oderwat.indent-rainbow
      bradlc.vscode-tailwindcss
      usernamehw.errorlens
      eamodio.gitlens
      streetsidesoftware.code-spell-checker
      formulahendry.auto-close-tag
      formulahendry.auto-rename-tag
      yoavbls.pretty-ts-errors
      pkief.material-icon-theme
      ms-vscode.vscode-typescript-next
    ];
    userSettings = {
      # --- Formatting
      "editor.formatOnSave" = true;
      "[javascript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[typescript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[javascriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[typescriptreact]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[json]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[markdown]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };

      # Prettier--------------------
      "prettier.printWidth" = 100;
      "prettier.singleQuote" = true;
      "prettier.trailingComma" = "all";
      "prettier.semi" = true;

      # --- Terminal  ---
      "terminal.integrated.defaultProfile.linux" = "fish";
      "terminal.integrated.profiles.linux" = {
        fish = {
          path = "${pkgs.fish}/bin/fish";
          icon = "🐟";
        };
      };

      # -------UI------
      "eslint.validate" = [
        "javascript"
        "javascriptreact"
        "typescript"
        "typescriptreact"
        "json"
      ];
      "editor.tabSize" = 2;
      "editor.minimap.enabled" = false;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;

      # Indent Rainbow
      "indentRainbow.errorColor" = "rgba(255,127,127,0.8)";
      "indentRainbow.showFirstIndentGuides" = true;
    };
  };
}
