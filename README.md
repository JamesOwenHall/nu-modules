# nu modules

This repository contains custom modules for [Nu](https://www.nushell.sh/) that I use.

## kubectl

```
> help modules kubectl
Module for kubernetes. All commands throughout the module honour the KUBE_CONTEXT and KUBE_NAMESPACE environment
variables. This allows you to use different contexts and namespaces between multiple open terminal sessions.

Module: kubectl

Exported commands:
  k, k clear, k get, k kubeconfig, k namespace, k switch

Exported aliases:
  k ns, k sw

This module does not export environment.
```

```
> help k
Wrapper for kubectl that honours the KUBE_CONTEXT and KUBE_NAMESPACE environment variables.

Usage:
  > k {flags} ...($rest)

Subcommands:
  k clear (custom) - Clear the context and namespace.
  k get (custom) - Wrapper for kubectl get. Parses the output into a table if possible. When selecting a single resource, it's printed as
YAML by default.
  k kubeconfig (custom) - Get the context and namespace from the kubeconfig.
  k namespace (alias) - Alias for k namespace
  k namespace (custom) - Switch namespace.
  k switch (alias) - Alias for k switch
  k switch (custom) - Switch context and namespace.

Flags:
  --context <string>: The context to use.
  -n, --namespace <string>: The namespace to use.

Parameters:
  ...$rest <any>

Input/output types:
  ╭───┬─────────┬────────╮
  │ # │  input  │ output │
  ├───┼─────────┼────────┤
  │ 0 │ nothing │ any    │
  ╰───┴─────────┴────────╯
```