FROM rocker/r-ver:4.4.1

# Build from scratch: (to build faster using cache: remove the --no-cache option)
# $ docker build \
#     --no-cache \
#     --progress=plain \
#     --file Dockerfile.cstories_beta \
#     --tag cstories_beta . 2>&1 | tee build.cstories_beta.log

# Notes:
#   . warn=2 in upcoming R commands: increases warnings to errors
#   . Ncpus enables multicore builds to reduce build time

# These values persist in this Dockerfile AND the container
ENV \
  SHINY_APP_NAME=cstories_beta \
  SHINY_APP_VERSION=1.0 \
  RENV_VERSION=1.0.3

# OS and R required installs
RUN apt-get update && apt-get install --no-install-recommends -y \
    libcurl4-openssl-dev \
    libssl-dev \
    make \
    cmake \
    pandoc \
    imagemagick \
    libmagick++-dev \
    gsfonts \
    libgdal-dev \
    gdal-bin \
    libgeos-dev \
    libproj-dev \
    libsqlite3-dev \
    libpng-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libudunits2-dev \
    libxml2-dev \
    libharfbuzz-dev \
    libfribidi-dev \
&& rm -rf /var/lib/apt/lists/*

# Install renv
RUN R -q -e "options(warn=2); \
             options(Ncpus = parallel::detectCores()); \
             install.packages('remotes'); \
             remotes::install_version('renv', '${RENV_VERSION}')"

RUN R -q -e "install.packages(c('aws.s3', 'aws.signature', 'bs4Dash', 'bsicons', 'cicerone', 'cmocean', 'config', 'DT', 'echarts4r', 'ggpubr', 'golem', 'leafpop', 'magick', 'openair', 'paws', 'plotly', 'reactable', 'reshape2', 'sf', 'shinybrowser', 'shinyjs', 'shinyWidgets', 'waiter'), dependencies = TRUE, repos = 'https://cloud.r-project.org/')" > /install_packages.log 2>&1

# Install the R packages
WORKDIR /build
COPY renv.lock /build/renv.lock
RUN R -q -e "options(warn=2); \
             options(Ncpus = parallel::detectCores()); \
             renv::restore()"

ADD copy_env.sh /etc/cont-init.d/04_copy_env.sh

# Add local files and folders
#COPY R           /build/package_dir/R
#COPY inst        /build/package_dir/inst
COPY NAMESPACE   /build/package_dir/NAMESPACE
COPY DESCRIPTION /build/package_dir/DESCRIPTION
COPY . /build/package_dir

# Install the app package
RUN R CMD INSTALL /build/package_dir

# Remove the temporary directory
RUN rm -rf /build

# Set the working directory
WORKDIR /shiny/
#COPY inputs /shiny/inputs/
#COPY inst /shiny/inst/

# Increase disk space in the ImageMagick policy file
RUN sed -i 's/policy domain="resource" name="disk" value="1GiB"/policy domain="resource" name="disk" value="4GiB"'/ /etc/ImageMagick-6/policy.xml

# Container will be reachable on this port
EXPOSE 3838

# When the pod is spawned, run the ShinyApp
CMD ["R", "-e", "options('shiny.port'=3838,shiny.host='0.0.0.0');library(CStoriesBeta);CStoriesBeta::run_app()"]

