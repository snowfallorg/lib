{ core-inputs
, user-inputs
, snowfall-lib
, snowfall-config
}:

let
  inherit (core-inputs.nixpkgs.lib)
    assertMsg
    foldl
    head
    tail
    concatMap
    optionalAttrs
    optional
    mkIf
    filterAttrs
    mapAttrs'
    mkMerge
    mapAttrsToList
    optionals
    mkDefault
    mkAliasDefinitions
    mkAliasAndWrapDefinitions
    mkOption
    types;

  user-homes-root = snowfall-lib.fs.get-snowfall-file "homes";
  user-modules-root = snowfall-lib.fs.get-snowfall-file "modules";
in
{
  home = rec {
    # Modules in home-manager expect `hm` to be available directly on `lib` itself.
    home-lib =
      # @NOTE(jakehamilton): This prevents an error during evaluation if the input does
      # not exist.
      if user-inputs ? home-manager then
        snowfall-lib.internal.system-lib.extend
          (final: prev:
            # @NOTE(jakehamilton): This order is important, this library's extend and other utilities must write
            # _over_ the original `system-lib`.
            snowfall-lib.internal.system-lib
            // prev
            // {
              hm = snowfall-lib.internal.system-lib.home-manager.hm;
            })
      else
        { };

    ## Get the user and host from a combined string.
    ## Example Usage:
    ## ```nix
    ## split-user-and-host "myuser@myhost"
    ## ```
    ## Result:
    ## ```nix
    ## { user = "myuser"; host = "myhost"; }
    ## ```
    #@ String -> Attrs
    split-user-and-host = target:
      let
        raw-name-parts = builtins.split "@" target;
        name-parts = builtins.filter builtins.isString raw-name-parts;

        user = builtins.elemAt name-parts 0;
        host =
          if builtins.length name-parts > 1 then
            builtins.elemAt name-parts 1
          else
            "";
      in
      {
        inherit user host;
      };


    ## Create a home.
    ## Example Usage:
    ## ```nix
    ## create-home { path = ./homes/my-home; }
    ## ```
    ## Result:
    ## ```nix
    ## <flake-utils-plus-home-configuration>
    ## ```
    #@ Attrs -> Attrs
    create-home =
      { path
      , name ? builtins.unsafeDiscardStringContext (snowfall-lib.system.get-inferred-system-name path)
      , modules ? [ ]
      , specialArgs ? { }
      , channelName ? "nixpkgs"
      , system ? "x86_64-linux"
      }:
      let
        user-metadata = split-user-and-host name;

        # @NOTE(jakehamilton): home-manager has trouble with `pkgs` recursion if it isn't passed in here.
        pkgs = user-inputs.self.pkgs.${system}.${channelName} // { lib = home-lib; };
        lib = home-lib;
      in
      assert assertMsg (user-inputs ? home-manager) "In order to create home-manager configurations, you must include `home-manager` as a flake input.";
      assert assertMsg (user-metadata.host != "") "Snowfall Lib homes must be named with the format: user@system";
      {
        inherit channelName system;

        output = "homeConfigurations";

        modules = [
          path
          ../../modules/home/user/default.nix
        ] ++ modules;

        specialArgs = {
          inherit name;
          inherit (user-metadata) user host;

          format = "home";

          inputs = snowfall-lib.flake.without-src user-inputs;

          # @NOTE(jakehamilton): home-manager has trouble with `pkgs` recursion if it isn't passed in here.
          inherit pkgs lib;
        };

        builder = args:
          user-inputs.home-manager.lib.homeManagerConfiguration
            ((builtins.removeAttrs args [ "system" "specialArgs" ]) // {
              inherit pkgs lib;

              modules = args.modules ++ [
                (module-args: import ./nix-registry-module.nix (module-args // {
                  inherit user-inputs core-inputs;
                }))
                ({
                  snowfallorg.user = {
                    name = mkDefault user-metadata.user;
                    enable = mkDefault true;
                  };
                })
              ];

              extraSpecialArgs = specialArgs // args.specialArgs;
            });
      };

    ## Get structured data about all homes for a given target.
    ## Example Usage:
    ## ```nix
    ## get-target-homes-metadata ./homes
    ## ```
    ## Result:
    ## ```nix
    ## [ { system = "x86_64-linux"; name = "my-home"; path = "/homes/x86_64-linux/my-home";} ]
    ## ```
    #@ String -> [Attrs]
    get-target-homes-metadata = target:
      let
        homes = snowfall-lib.fs.get-directories target;
        existing-homes = builtins.filter (home: builtins.pathExists "${home}/default.nix") homes;
        create-home-metadata = path: {
          path = "${path}/default.nix";
          # We are building flake outputs based on file contents. Nix doesn't like this
          # so we have to explicitly discard the string's path context to allow us to
          # use the name as a variable.
          name = builtins.unsafeDiscardStringContext (builtins.baseNameOf path);
          # We are building flake outputs based on file contents. Nix doesn't like this
          # so we have to explicitly discard the string's path context to allow us to
          # use the name as a variable.
          system = builtins.unsafeDiscardStringContext (builtins.baseNameOf target);
        };
        home-configurations = builtins.map create-home-metadata existing-homes;
      in
      home-configurations;

    ## Create all available homes.
    ## Example Usage:
    ## ```nix
    ## create-homes { users."my-user@my-system".specialArgs.x = true; modules = [ my-shared-module ]; }
    ## ```
    ## Result:
    ## ```nix
    ## { "my-user@my-system" = <flake-utils-plus-home-configuration>; }
    ## ```
    #@ Attrs -> Attrs
    create-homes = homes:
      let
        targets = snowfall-lib.fs.get-directories user-homes-root;
        target-homes-metadata = concatMap get-target-homes-metadata targets;

        user-home-modules = snowfall-lib.module.create-modules {
          src = "${user-modules-root}/home";
        };

        user-home-modules-list = mapAttrsToList
          (module-path: module: args@{ pkgs, ... }: (module args) // {
            _file = "${user-homes-root}/${module-path}/default.nix";
          })
          user-home-modules;

        create-home' = home-metadata:
          let
            inherit (home-metadata) name;
            overrides = homes.users.${name} or { };
          in
          {
            "${name}" = create-home (overrides // home-metadata // {
              modules = user-home-modules-list ++ (homes.users.${name}.modules or [ ]) ++ (homes.modules or [ ]);
            });
          };

        created-homes = foldl (homes: home-metadata: homes // (create-home' home-metadata)) { } target-homes-metadata;
      in
      created-homes;

    ## Create system modules for home-manager integration.
    ## Example Usage:
    ## ```nix
    ## create-home-system-modules { users."my-user@my-system".specialArgs.x = true; modules = [ my-shared-module ]; }
    ## ```
    ## Result:
    ## ```nix
    ## [Module]
    ## ```
    #@ Attrs -> [Module]
    create-home-system-modules = users:
      let
        created-users = create-homes users;
        user-home-modules = snowfall-lib.module.create-modules {
          src = "${user-modules-root}/home";
        };

        shared-modules = mapAttrsToList
          (module-path: module: {
            _file = "${user-modules-root}/home/${module-path}/default.nix";

            config = {
              home-manager.sharedModules = [ module ];
            };
          })
          user-home-modules;

        snowfall-user-home-module = {
          _file = "virtual:snowfallorg/modules/home/user/default.nix";

          config = {
            home-manager.sharedModules = [
              ../../modules/home/user/default.nix
            ];
          };
        };

        extra-special-args-module =
          args@{ config
          , pkgs
          , system ? pkgs.system
          , target ? system
          , format ? "home"
          , host ? ""
          , virtual ? (snowfall-lib.system.is-virtual target)
          , systems ? { }
          , ...
          }:
          {
            _file = "virtual:snowfallorg/home/extra-special-args";

            config = {
              home-manager.extraSpecialArgs = {
                inherit system target format virtual systems host;

                lib = home-lib;

                inputs = snowfall-lib.flake.without-src user-inputs;
              };
            };
          };

        system-modules = builtins.map
          (name:
            let
              created-user = created-users.${name};
              user-module = head created-user.modules;
              other-modules = users.users.${name}.modules or [ ];
              user-name = created-user.specialArgs.user;
            in
            args@{ config
            , options
            , pkgs
            , host ? ""
            , ...
            }:
            let
              host-matches = created-user.specialArgs.host == host;

              # @NOTE(jakehamilton): To conform to the config structure of home-manager, we have to
              # remap the options coming from `snowfallorg.user.<name>.home.config` since `mkAliasDefinitions`
              # does not let us target options within a submodule.
              wrap-user-options = user-option:
                if (user-option ? "_type") && user-option._type == "merge" then
                  user-option // {
                    contents = builtins.map
                      (merge-entry:
                        merge-entry.${user-name}.home.config or { }
                      )
                      user-option.contents;
                  }
                else
                  (builtins.trace ''
                    =============
                    Snowfall Lib:
                    Option value for `snowfallorg.user.${user-name}` was not detected to be merged.

                    Please report the issue on GitHub with a link to your configuration so we can debug the problem:
                      https://github.com/snowfallorg/lib/issues/new
                    =============
                  '')
                    user-option;

              home-config = mkAliasAndWrapDefinitions wrap-user-options options.snowfallorg.user;
            in
            {
              _file = "virtual:snowfallorg/home/user/${name}";

              config = mkIf host-matches {
                # Initialize user information.
                snowfallorg.user.${user-name}.home.config = {
                  snowfallorg.user = {
                    enable = true;
                    name = mkDefault user-name;
                  };
                  home.stateVersion = "22.11";
                };

                home-manager = {
                  users.${user-name} = mkIf config.snowfallorg.user.${user-name}.home.enable ({ pkgs, ... }: {
                    imports = (home-config.imports or [ ]) ++ other-modules ++ [user-module];
                    config = home-config;
                  });

                  # NOTE: Without this home-manager will instead create its own package set which won't contain the same config and
                  # user-defined packages/overlays as the flake's nixpkgs channel.
                  useGlobalPkgs = mkDefault true;
                };
              };
            }
          )
          (builtins.attrNames created-users);
      in
      [
        extra-special-args-module
        snowfall-user-home-module
      ]
      ++ shared-modules
      ++ system-modules;
  };
}
