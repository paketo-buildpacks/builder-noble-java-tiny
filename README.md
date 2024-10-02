# Paketo Noble Java Tiny Builder

## `paketobuildpacks/builder-noble-java-tiny:latest`

This builder uses the [Paketo Noble Tiny
Stack](https://github.com/paketo-buildpacks/noble-tiny-stack) (an Ubuntu Noble
tiny image) and contains **only Java composite buildpacks**. To use this
builder, you can rely on the default order group.

For example, with the `pack` CLI, use `--builder` as follows:
```bash
pack build great-java-app \
--builder paketobuildpacks/builder-noble-java-tiny:latest
```

To see which versions of build and run images and the lifecycle are contained
within a given builder version, see the
[Releases](https://github.com/paketo-buildpacks/builder-noble-java-tiny/releases)
on this repo. This information is also available in the `builder.toml`.

For more information about this builder and how to use it, visit the [Paketo
builder documentation](https://paketo.io/docs/builders/).  To learn about the
stack included in this builder, visit the [Paketo stack
documentation](https://paketo.io/docs/stacks/).

