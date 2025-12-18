# Module for kubernetes. All commands throughout the module honour the KUBE_CONTEXT and KUBE_NAMESPACE environment
# variables. This allows you to use different contexts and namespaces between multiple open terminal sessions.

# Wrapper for kubectl that honours the KUBE_CONTEXT and KUBE_NAMESPACE environment variables.
export def --wrapped k [
  --context:string # The context to use.
  --namespace (-n):string # The namespace to use.
  ...$rest
] : nothing -> any {
  kubectl --context=($context) --namespace=($namespace) ...$rest
}

# Alias for kubectl get.
export def --wrapped "k get" [
  --context:string # The context to use.
  --namespace (-n):string # The namespace to use.
  --output:string # The output format to use.
  --watch (-w) # Watch for changes.
  ...$rest
]: nothing -> any {
  if $watch {
    error make {
      code: "kubectl::watch_mode_not_supported",
      msg: "Watch mode is not supported."
      help: $"Use `^kubectl get --context=($context | default $env.KUBE_CONTEXT?) --namespace=($namespace | default $env.KUBE_NAMESPACE?) --watch` instead."
    }
  }

  # Check if the user is setting an output format. Unless it's just "wide", we don't try to parse it.
  let shorthand_output_set = $rest | any { ($in | str starts-with "-o") and ($in != "-owide") }
  if ($output != null and $output != "wide") or $shorthand_output_set {
    return (kubectl get ...$rest --context=($context) --namespace=($namespace) --output=($output))
  }

  let result = kubectl get ...$rest --context=($context) --namespace=($namespace) --output=($output)

  let num_non_flag_args = $rest | where not ($it | str starts-with "-") | length
  if $num_non_flag_args != 1 {
    return $result
  }

  $result | from k8s-table
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
  --no-kubeconfig # Don't clear the current context from the KUBECONFIG.
] : nothing -> nothing {
  if not $no_context {
    hide-env -i KUBE_CONTEXT
  }
  if not $no_namespace {
    hide-env -i KUBE_NAMESPACE
  }
  if not $no_kubeconfig {
    ^kubectl config unset current-context
  }
}

def --wrapped kubectl [
  --context:string # The context to use.
  --namespace (-n):string # The namespace to use.
  ...$rest
]: nothing -> any {
  let context = $context | default ($env.KUBE_CONTEXT?)
  let namespace = $namespace | default ($env.KUBE_NAMESPACE?)
  ^kubectl --context=($context) --namespace=($namespace) ...$rest
}

def "from k8s-table" []: string -> any {
  let input = $in
  try {
    $input | detect columns | update AGE? { from go-duration }
  } catch {
    $input
  }
}

def "from go-duration" []: string -> duration {
  let units: record = {
    d: "day",
    h: "hr",
    m: "min",
    s: "sec",
    ms: "ms",
    µs: "µs",
    ns: "ns",
  }

  $in | parse -r '(\d+[a-zµ]+)' | get capture0 | each {
    let go_unit: string = $in | parse -r '([a-zµ]+)' | first | get capture0
    let num = $in | parse -r '(\d+)' | first | get capture0
    $"($num)($units | get $go_unit)"
  } | str join " " | into duration
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
