# Module for kubernetes. All commands throughout the module honour the KUBE_CONTEXT and KUBE_NAMESPACE environment
# variables. This allows you to use different contexts and namespaces between multiple open terminal sessions.

# Wrapper for kubectl that honours the KUBE_CONTEXT and KUBE_NAMESPACE environment variables.
export def --wrapped k [
  --context:string # The context to use.
  --namespace (-n):string # The namespace to use.
  ...$rest
] : nothing -> any {
  kubectl ...$rest --context=($context) --namespace=($namespace)
}

# Wrapper for kubectl get. Parses the output into a table if possible. When selecting a single resource, it's printed as
# YAML by default.
export def --wrapped "k get" [
  --context:string # The context to use.
  --namespace (-n):string # The namespace to use.
  --no-parse # Don't parse the output into a table.
  --output:string # The output format to use.
  --watch (-w) # Watch the resource. Watch mode does not support parsing the output into a table.
  ...$rest
] : nothing -> any {
  if $watch {
    # To support watch mode, we need to run the command directly without capturing the output.
    kubectl get --context=($context) --namespace=($namespace) --output=($output) --watch ...$rest
    return
  }

  if $no_parse or ($output != null and $output != "wide") {
    return (kubectl get --context=($context) --namespace=($namespace) --output=($output) ...$rest)
  }

  # Nushell doesn't parse shorthand flags without spaces (e.g. -ojson). Skip parsing it.
  if ($rest | any { $in | str starts-with "-o" }) {
    return (kubectl get --context=($context) --namespace=($namespace) ...$rest)
  }

  let non_flag_args = $rest | where { not ($in | str starts-with "-") }
  match ($non_flag_args | length) {
    0 => (kubectl get --context=($context) --namespace=($namespace) --output=($output) ...$rest)
    # Selecting a particular resource.
    2 => {
      let output = $output | default "yaml"
      kubectl get --context=($context) --namespace=($namespace) --output=($output) ...$rest
    }
    # Listing resources of a given type. If the length is 1, we're listing all resources of that type. If the length is
    # greater than 2, we're listing multiple resources of that type. Either way, parse the output into a table.
    _ => {
      kubectl get --context=($context) --namespace=($namespace) --output=($output) ...$rest
        | from ssv -a
        | update AGE? { from go-duration }  
    }
  }
}

# Switch context and namespace.
export def --env "k switch" [
  context: string@context-completions # The context to use.
  namespace?: string # The namespace to use.
] : nothing -> record<context: string, namespace: string> {
  $env.KUBE_CONTEXT = $context
  if $namespace != null {
    $env.KUBE_NAMESPACE = $namespace
  }

  { context: $context, namespace: $namespace }
}
export alias "k sw" = k switch

# Switch namespace.
export def --env "k namespace" [
  namespace: string # The namespace to use.
] : nothing -> string {
  $env.KUBE_NAMESPACE = $namespace
  $namespace
}
export alias "k ns" = k namespace

# Clear the context and namespace.
export def --env "k clear" [
  --no-context # Don't clear the KUBE_CONTEXT environment variable.
  --no-namespace # Don't clear the KUBE_NAMESPACE environment variable.
  --kubeconfig (-k) # Clear the current context from the KUBECONFIG.
] : nothing -> nothing {
  let env_context = $env.KUBE_CONTEXT?
  let kubeconfig_context = ^kubectl config current-context | complete | get stdout | str trim | default -e null

  if not $no_context {
    hide-env -i KUBE_CONTEXT
  }
  if not $no_namespace {
    hide-env -i KUBE_NAMESPACE
  }
  if $kubeconfig {
    if $env_context != null {
      ^kubectl config unset contexts.($env_context).namespace | ignore
    }
    if $kubeconfig_context != null {
      ^kubectl config unset contexts.($kubeconfig_context).namespace | ignore
    }

    ^kubectl config unset current-context | ignore
  }
}

# Get the context and namespace from the kubeconfig.
export def "k kubeconfig" []: nothing -> record<context: string, namespace: string> {
  let kubeconfig_context = ^kubectl config current-context | complete | get stdout | str trim | default -e null
  if $kubeconfig_context == null {
    return null
  }

  let kubeconfig_namespace = ^kubectl config view --minify --output 'jsonpath={..namespace}'
  { context: $kubeconfig_context, namespace: $kubeconfig_namespace }
}

def --wrapped kubectl [
  --context:string # The context to use.
  --namespace (-n):string # The namespace to use.
  ...$rest
]: nothing -> any {
  let context = $context | default ($env.KUBE_CONTEXT?)
  let namespace = $namespace | default ($env.KUBE_NAMESPACE?)
  ^kubectl ...$rest  --context=($context) --namespace=($namespace)
}

def context-completions []: nothing -> record<completions: list<string>, options: record<completion_algorithm: string>> {
  let paths = $env.KUBECONFIG | split row ":" | uniq
  let contexts = $paths | each {
    if not ($in | path exists) {
      return null
    }

    open $in --raw
    | from yaml
    | get contexts
    | get name
  } | compact | flatten | uniq

  {
    completions: $contexts,
    options: {
      completion_algorithm: "fuzzy",
    },
  }
}

def "from go-duration" []: string -> any {
  let go_units = {
    "ns": "ns",
    "µs": "µs",
    "ms": "ms",
    "s": "sec",
    "m": "min",
    "h": "hr",
    "d": "day",
  }

  let match = $in | parse -r '(\d+)([a-z]+)'
  if ($match | is-empty) {
    # Not a valid go duration. Just return the input.
    return $in
  }

  $match | each {
    let value = $in.capture0 | into int
    let go_unit = $in.capture1
    let unit = $go_units | get $go_unit
    $"($value)($unit)"
  } | str join " " | into duration
}
