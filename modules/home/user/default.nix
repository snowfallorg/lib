inputs@{ pkgs, lib, options, config, ... }:

let
  inherit (lib) types mkOption mkIf mkDefault;

  cfg = config.snowfallorg;

  # @NOTE(jakehamilton): The module system chokes if it finds `osConfig` named in the module arguments
  # when being used in standalone home-manager. To remedy this, we have to refer to the arguments set directly.
  os-user-home = inputs.osConfig.users.users.${cfg.name}.home or null;

  default-home-directory =
    if (os-user-home != null) then
      os-user-home
    else if pkgs.stdenv.isDarwin then
      "/Users/${cfg.user.name}"
    else
      "/home/${cfg.user.name}";
in
{
  options.snowfallorg = {
    user = {
      enable = mkOption {
        type = types.bool;
        default = true;
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
      username = mkIf (cfg.user.name or null != null) (mkDefault cfg.user.name);
      homeDirectory = mkIf (cfg.user.name or null != null) (mkDefault cfg.user.home.directory);
    };
  };
}
