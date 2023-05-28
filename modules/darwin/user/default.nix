{ pkgs, lib, options, config, ... }:

let
  inherit (lib) types mkOption mkDefault foldl optionalAttrs;

  cfg = config.snowfallorg;

  user-names = builtins.attrNames cfg.user;

  create-system-users = system-users: name:
    let
      user = cfg.user.${name};
    in
    system-users // (optionalAttrs user.create {
      ${name} = {
        home = mkDefault user.home.path;
        isHidden = mkDefault false;
      };
    });

  create-resolved-home = resolved-homes: name:
    let
      user = cfg.user.${name};
    in
    resolved-homes // {
      ${name} = user.home.config;
    };
in
{
  options.snowfallorg = {
    user = mkOption {
      description = "User configuration.";
      default = { };
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          create = mkOption {
            description = "Whether to create the user automatically.";
            type = types.bool;
            default = true;
          };

          home = {
            path = mkOption {
              type = types.str;
              default = "/Users/${name}";
            };

            config = mkOption {
              type = types.attrs;
              default = { };
            };
          };
        };
      }));
    };

    resolved-homes = mkOption {
      type = types.attrs;
      default = { };
      internal = true;
    };
  };

  config = {
    users.users = (foldl (create-system-users) { } (user-names));

    snowfallorg = {
      resolved-homes = (foldl (create-resolved-home) { } (user-names));
    };
  };
}
