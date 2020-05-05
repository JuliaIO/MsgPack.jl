FROM julia:0.7

ENV JULIA_PROJECT /src/msgpack
RUN mkdir -p $JULIA_PROJECT
WORKDIR $JULIA_PROJECT
COPY Project.toml Project.toml
RUN julia -e 'using Pkg; Pkg.instantiate(); Pkg.status()'

COPY src src
COPY test test

CMD ["julia", "-e", "using Pkg; Pkg.test()"]
