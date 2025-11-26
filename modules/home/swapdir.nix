{ config, lib, pkgs, ... }:

let
  cfg = config.programs.swapdir;
in
{
  options.programs.swapdir = {
    enable = lib.mkEnableOption "swapdir - cross-shell directory path swapping utility";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.swapdir;
      defaultText = lib.literalExpression "pkgs.swapdir";
      description = "The swapdir package to use.";
    };

    enableBashIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Bash integration.";
    };

    enableZshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Zsh integration.";
    };

    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Fish integration.";
    };

    enableNushellIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Nushell integration.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.bash.initExtra = lib.mkIf cfg.enableBashIntegration ''
      source ${cfg.package}/share/swapdir/swapdir.bash
    '';

    programs.zsh.initExtra = lib.mkIf cfg.enableZshIntegration ''
      source ${cfg.package}/share/swapdir/swapdir.zsh
    '';

    programs.fish.interactiveShellInit = lib.mkIf cfg.enableFishIntegration ''
      source ${cfg.package}/share/swapdir/swapdir.fish
    '';

    programs.nushell.extraConfig = lib.mkIf cfg.enableNushellIntegration ''
      source ${cfg.package}/share/swapdir/swapdir.nu
    '';
  };
}
