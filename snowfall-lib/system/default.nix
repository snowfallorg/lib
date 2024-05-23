{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (builtins) dirOf baseNameOf;
  inherit (core-inputs.nixpkgs.lib) assertMsg fix hasInfix concatMap foldl optionals singleton;

  virtual-systems = import ./virtual-systems.nix;

  user-systems-root = snowfall-lib.fs.get-snowfall-file "systems";
  user-modules-root = snowfall-lib.fs.get-snowfall-file "modules";
in {
  system = rec {
    ## Get the name of a system based on its file path.
    ## Example Usage:
    ## ```nix
    ## get-inferred-system-name "/systems/my-system/default.nix"
    ## ```
    ## Result:
    ## ```nix
    ## "my-system"
    ## ```
    #@ Path -> String
    get-inferred-system-name = path:
      if snowfall-lib.path.has-file-extension "nix" path
      then snowfall-lib.path.get-parent-directory path
      else baseNameOf path;

    ## Check whether a named system is macOS.
    ## Example Usage:
    ## ```nix
    ## is-darwin "x86_64-linux"
    ## ```
    ## Result:
    ## ```nix
    ## false
    ## ```
    #@ String -> Bool
    is-darwin = hasInfix "darwin";

    ## Check whether a named system is Linux.
    ## Example Usage:
    ## ```nix
    ## is-linux "x86_64-linux"
    ## ```
    ## Result:
    ## ```nix
    ## false
    ## ```
    #@ String -> Bool
    is-linux = hasInfix "linux";

    ## Check whether a named system is virtual.
    ## Example Usage:
    ## ```nix
    ## is-virtual "x86_64-iso"
    ## ```
    ## Result:
    ## ```nix
    ## true
    ## ```
    #@ String -> Bool
    is-virtual = target:
      (get-virtual-system-type target) != "";

    ## Get the virtual system type of a system target.
    ## Example Usage:
    ## ```nix
    ## get-virtual-system-type "x86_64-iso"
    ## ```
    ## Result:
    ## ```nix
    ## "iso"
    ## ```
    #@ String -> String
    get-virtual-system-type = target:
      foldl
      (
        result: virtual-system:
          if result == "" && hasInfix virtual-system target
          then virtual-system
          else result
      )
      ""
      virtual-systems;

    ## Get structured data about all systems for a given target.
    ## Example Usage:
    ## ```nix
    ## get-target-systems-metadata "x86_64-linux"
    ## ```
    ## Result:
    ## ```nix
    ## [ { target = "x86_64-linux"; name = "my-machine"; path = "/systems/x86_64-linux/my-machine"; } ]
    ## ```
    #@ String -> [Attrs]
    get-target-systems-metadata = target: let
      systems = snowfall-lib.fs.get-directories target;
      existing-systems = builtins.filter (system: builtins.pathExists "${system}/default.nix") systems;
      create-system-metadata = path: {
        path = "${path}/default.nix";
        # We are building flake outputs based on file contents. Nix doesn't like this
        # so we have to explicitly discard the string's path context to allow us to
        # use the name as a variable.
        name = builtins.unsafeDiscardStringContext (builtins.baseNameOf path);
        # We are building flake outputs based on file contents. Nix doesn't like this
        # so we have to explicitly discard the string's path context to allow us to
        # use the name as a variable.
        target = builtins.unsafeDiscardStringContext (builtins.baseNameOf target);
      };
      system-configurations = builtins.map create-system-metadata existing-systems;
    in
      system-configurations;

    ## Get the system builder for a given target.
    ## Example Usage:
    ## ```nix
    ## get-system-builder "x86_64-iso"
    ## ```
    ## Result:
    ## ```nix
    ## (args: <system>)
    ## ```
    #@ String -> Function
    get-system-builder = target: let
      virtual-system-type = get-virtual-system-type target;
      virtual-system-builder = args:
        assert assertMsg (user-inputs ? nixos-generators) "In order to create virtual systems, you must include `nixos-generators` as a flake input.";
          user-inputs.nixos-generators.nixosGenerate
          (args
            // {
              format = virtual-system-type;
              specialArgs =
                args.specialArgs
                // {
                  format = virtual-system-type;
                };
              modules =
                args.modules
                ++ [
                  ../../modules/nixos/user/default.nix
                ];
            });
      darwin-system-builder = args:
        assert assertMsg (user-inputs ? darwin) "In order to create virtual systems, you must include `darwin` as a flake input.";
          user-inputs.darwin.lib.darwinSystem
          ((builtins.removeAttrs args ["system" "modules"])
            // {
              specialArgs =
                args.specialArgs
                // {
                  format = "darwin";
                };
              modules =
                args.modules
                ++ [
                  ../../modules/darwin/user/default.nix
                ];
            });
      linux-system-builder = args:
        core-inputs.nixpkgs.lib.nixosSystem
        (args
          // {
            specialArgs =
              args.specialArgs
              // {
                format = "linux";
              };
            modules =
              args.modules
              ++ [
                ../../modules/nixos/user/default.nix
              ];
          });
    in
      if virtual-system-type != ""
      then virtual-system-builder
      else if is-darwin target
      then darwin-system-builder
      else linux-system-builder;

    ## Get the flake output attribute for a system target.
    ## Example Usage:
    ## ```nix
    ## get-system-output "aarch64-darwin"
    ## ```
    ## Result:
    ## ```nix
    ## "darwinConfigurations"
    ## ```
    #@ String -> String
    get-system-output = target: let
      virtual-system-type = get-virtual-system-type target;
    in
      if virtual-system-type != ""
      then "${virtual-system-type}Configurations"
      else if is-darwin target
      then "darwinConfigurations"
      else "nixosConfigurations";

    ## Get the resolved (non-virtual) system target.
    ## Example Usage:
    ## ```nix
    ## get-resolved-system-target "x86_64-iso"
    ## ```
    ## Result:
    ## ```nix
    ## "x86_64-linux"
    ## ```
    #@ String -> String
    get-resolved-system-target = target: let
      virtual-system-type = get-virtual-system-type target;
    in
      if virtual-system-type != ""
      then builtins.replaceStrings [virtual-system-type] ["linux"] target
      else target;

    ## Create a system.
    ## Example Usage:
    ## ```nix
    ## create-system { path = ./systems/my-system; }
    ## ```
    ## Result:
    ## ```nix
    ## <flake-utils-plus-system-configuration>
    ## ```
    #@ Attrs -> Attrs
    create-system = {
      target ? "x86_64-linux",
      system ? get-resolved-system-target target,
      path,
      name ? builtins.unsafeDiscardStringContext (get-inferred-system-name path),
      modules ? [],
      specialArgs ? {},
      channelName ? "nixpkgs",
      builder ? get-system-builder target,
      output ? get-system-output target,
      systems ? {},
      homes ? {},
    }: let
      lib = snowfall-lib.internal.system-lib;
      home-system-modules = snowfall-lib.home.create-home-system-modules homes;
      home-manager-module =
        if is-darwin system
        then user-inputs.home-manager.darwinModules.home-manager
        else user-inputs.home-manager.nixosModules.home-manager;
      home-manager-modules = [home-manager-module] ++ home-system-modules;
    in {
      inherit channelName system builder output;

      modules = [path] ++ modules ++ (optionals (user-inputs ? home-manager) home-manager-modules);

      specialArgs =
        specialArgs
        // {
          inherit target system systems lib;
          host = name;

          virtual = (get-virtual-system-type target) != "";
          inputs = snowfall-lib.flake.without-src user-inputs;
          namespace = snowfall-config.namespace;
        };
    };

    ## Create all available systems.
    ## Example Usage:
    ## ```nix
    ## create-systems { hosts.my-host.specialArgs.x = true; modules.nixos = [ my-shared-module ]; }
    ## ```
    ## Result:
    ## ```nix
    ## { my-host = <flake-utils-plus-system-configuration>; }
    ## ```
    #@ Attrs -> Attrs
    create-systems = {
      systems ? {},
      homes ? {},
    }: let
      targets = snowfall-lib.fs.get-directories user-systems-root;
      target-systems-metadata = concatMap get-target-systems-metadata targets;
      user-nixos-modules = snowfall-lib.module.create-modules {
        src = "${user-modules-root}/nixos";
      };
      user-darwin-modules = snowfall-lib.module.create-modules {
        src = "${user-modules-root}/darwin";
      };
      nixos-modules = systems.modules.nixos or [];
      darwin-modules = systems.modules.darwin or [];

      create-system' = created-systems: system-metadata: let
        overrides = systems.hosts.${system-metadata.name} or {};
        user-modules =
          if is-darwin system-metadata.target
          then user-darwin-modules
          else user-nixos-modules;
        user-modules-list = builtins.attrValues user-modules;
        system-modules =
          if is-darwin system-metadata.target
          then darwin-modules
          else nixos-modules;
      in {
        ${system-metadata.name} = create-system (overrides
          // system-metadata
          // {
            systems = created-systems;
            modules = user-modules-list ++ (overrides.modules or []) ++ system-modules;
            inherit homes;
          });
      };
      created-systems = fix (
        created-systems:
          foldl
          (
            systems: system-metadata:
              systems // (create-system' created-systems system-metadata)
          )
          {}
          target-systems-metadata
      );
    in
      created-systems;
  };
}
