{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (builtins) baseNameOf dirOf;
  inherit (core-inputs.nixpkgs.lib) id foldr flip;
in {
  fp = rec {
    ## Compose two functions.
    ## Example Usage:
    ## ```nix
    ## compose add-two add-one
    ## ```
    ## Result:
    ## ```nix
    ## (x: add-two (add-one x))
    ## ```
    #@ (b -> c) -> (a -> b) -> a -> c
    compose = f: g: x: f (g x);

    ## Compose many functions.
    ## Example Usage:
    ## ```nix
    ## compose-all [ add-two add-one ]
    ## ```
    ## Result:
    ## ```nix
    ## (x: add-two (add-one x))
    ## ```
    #@ [(x -> y)] -> a -> b
    compose-all = foldr compose id;

    ## Call a function with an argument.
    ## Example Usage:
    ## ```nix
    ## call (x: x + 1) 0
    ## ```
    ## Result:
    ## ```nix
    ## 1
    ## ```
    #@ (a -> b) -> a -> b
    call = f: x: f x;

    ## Apply an argument to a function.
    ## Example Usage:
    ## ```nix
    ## apply 0 (x: x + 1)
    ## ```
    ## Result:
    ## ```nix
    ## 1
    ## ```
    #@ a -> (a -> b) -> b
    apply = flip call;
  };
}
