{ pkgs, lib, options, config, inputs, ... }:

let
  inherit (lib) types mkOption mkDefault foldl optionalAttrs optional;

  cfg = config.snowfallorg;

  user-names = builtins.attrNames cfg.user;

  create-system-users = system-users: name:
    let
      user = cfg.user.${name};
    in
    system-users // (optionalAttrs user.create {
      ${name} = {
        isNormalUser = mkDefault true;

        name = mkDefault name;

        home = mkDefault user.home.path;
        group = mkDefault "users";

        extraGroups = optional user.admin "wheel";
      };
    });

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

          admin = mkOption {
            description = "Whether the user should be added to the wheel group.";
            type = types.bool;
            default = true;
          };

          home = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };

            path = mkOption {
              type = types.str;
              default = "/home/${name}";
            };

            config = mkOption {
              # HM-compatible options taken from:
              # https://github.com/nix-community/home-manager/blob/0ee5ab611dc1fbb5180bd7d88d2aeb7841a4d179/nixos/common.nix#L14
              type = types.submoduleWith {
                specialArgs = {
                  osConfig = config;
                  modulesPath = "${inputs.home-manager}/modules";
                } // config.home-manager.extraSpecialArgs;
                modules = [
                  ({ lib, modulesPath, ... }: {
                    imports = import "${modulesPath}/modules.nix" {
                      inherit pkgs lib;
                      useNixpkgsModule = !config.home-manager.useGlobalPkgs;
                    };

                    config = {
                      submoduleSupport.enable = true;
                      submoduleSupport.externalPackageInstall = cfg.useUserPackages;

                      home.username = config.users.users.${name}.name;
                      home.homeDirectory = config.users.users.${name}.home;

                      nix.package = config.nix.package;
                    };
                  })
                ] ++ config.home-manager.sharedModules;
              };
            };
          };
        };
      }));
    };
  };

  config = {
    users.users = (foldl (create-system-users) { } (user-names));
  };
}
