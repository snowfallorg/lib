{ lib, osConfig ? { }, ... }:

let
  inherit (lib) types mkOption;

  home-submodule = { name, ... }: {
    options = {
      proxy = mkOption {
        type = types.attrs;
        default = { };
        description = "Configuration to be proxied to the home-manager configuration for `home-manager.users.<name>`.";
      };
    };
  };
in
{
  options.snowfallorg = {
    home = mkOption {
      type = types.attrsOf (types.submodule home-submodule);
      default = { };
      description = "Options for configuring home environments.";
    };
  };

  config = {
    # snowfallorg.home = osConfig.snowfallorg.home or { };
  };
}
