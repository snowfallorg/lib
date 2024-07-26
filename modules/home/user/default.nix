inputs @ {
  pkgs,
  lib,
  options,
  config,
  ...
}: let
  inherit (lib) types mkOption mkIf mkDefault;

  cfg = config.snowfallorg;

  # NOTE: The module system chokes if it finds `osConfig` named in the module arguments
  # when being used in standalone home-manager. To remedy this, we have to refer to the arguments set directly.
  os-user-home = inputs.osConfig.users.users.${cfg.user.name}.home or null;

  has-user-name = (cfg.user.name or null) != null;

  default-home-directory =
    if (os-user-home != null)
    then os-user-home
    else if pkgs.stdenv.isDarwin
    then "/Users/${cfg.user.name}"
    else "/home/${cfg.user.name}";
in {
  options.snowfallorg = {
    user = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to configure the user.";
      };

      name = mkOption {
        type = types.str;
        description = "The user's name.";
      };

      home = {
        directory = mkOption {
          type = types.str;
          description = "The user's home directory.";
          default = default-home-directory;
        };
      };
    };
  };

  config = mkIf cfg.user.enable {
    home = {
      username = mkIf has-user-name (mkDefault cfg.user.name);
      homeDirectory = mkIf has-user-name (mkDefault cfg.user.home.directory);
    };
  };
}
