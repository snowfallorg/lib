{ lib, options, ... }:

let
  inherit (lib) types mkOption mkIf mkMerge mkAliasDefinitions;

  cfg = options.snowfallorg;
in
{
  options.snowfallorg = {
    home = mkOption {
      description = "Configuration for home-manager.";
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options.config = {
          type = types.attrs;
          default = { };
        };
      }));
    };

    resolvedHomes = mkOption {
      type = types.attrs;
      default = { };
    };
  };

  config = mkMerge (builtins.map
    (name: {
      snowfallorg.resolvedHomes.${name} = mkAliasDefinitions options.snowfallorg.home.${name}.config;
    })
    (builtins.attrNames cfg.home));
}
