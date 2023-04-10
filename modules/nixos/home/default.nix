{ lib, config, ... }:

let
  inherit (lib) types mkOption mkMerge mapAttrsToList;

  home-submodule = { name, ... }: {
    options = {
      proxy = mkOption {
        type = types.attrs;
        default = { };
        description = "Configuration to be proxied to the home-manager configuration for `home-manager.users.<name>`.";
      };
    };
  };

  cfg = config.snowfallorg;
in
{
  options.snowfallorg = {
    home = mkOption {
      type = types.attrsOf (types.submodule home-submodule);
      default = { };
      description = "Options for configuring home environments.";
    };
  };

  config = mkMerge
    (mapAttrsToList
      (name: value: {
        home-manager.users.${name} = value.proxy;
      })
      (cfg.home));
}
