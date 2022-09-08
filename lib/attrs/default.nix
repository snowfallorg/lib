{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (core-inputs.nixpkgs.lib)
    assertMsg
    mapAttrsToList
    flatten
    fold
    recursiveUpdate
    mergeAttrs;
in
{
  attrs = {
    # Map and flatten an attribute set into a list.
    # Type: (a -> b -> [c]) -> Attrs -> [c]
    # Usage: map-concat-attrs-to-list (name: value: [name value]) { x = 1; y = 2; }
    #   result: [ "x" 1 "y" 2 ]
    map-concat-attrs-to-list = f: attrs:
      flatten (mapAttrsToList f attrs);

    # Recursively merge a list of attribute sets.
    # Type: [Attrs] -> Attrs
    # Usage: merge-deep [{ x = 1; } { x = 2; }]
    #   result: { x = 2; }
    merge-deep = fold recursiveUpdate { };

    # Merge the root of a list of attribute sets.
    # Type: [Attrs] -> Attrs
    # Usage: merge-shallow [{ x = 1; } { x = 2; }]
    #   result: { x = 2; }
    merge-shallow = fold mergeAttrs { };
  };
}
