#!/bin/bash
#
# NAME
#
#   make.sh
#
# SYNPOSIS
#
#   make.sh                     [-r <service>]                  \
#                               [-a <swarm-advertise-adr>]      \
#                               [-p] [-s] [-i]                  \
#                               [-U] [-I]                       \
#                               [-S <storeBaseOverride>]        \
#                               [-e <computeEnv>]               \
#                               [local|fnndsc[:dev]]
#
# DESC
#
#   'make.sh' is the main entry point for instantiating a
#   complete backend dev environment.
#
#   It creates a pattern of directories and symbolic links that reflect the
#   declarative environment of the docker-compose_dev.yml contents.
#
# TYPICAL CASES:
#
#   Run full CUBE instantiation with tests:
#
#       unmake.sh ; sudo rm -fr FS; rm -fr FS; make.sh
#
#   Skip unit and integration tests and the intro:
#
#       unmake.sh ; sudo rm -fr FS; rm -fr FS; make.sh -U -I -s
#
# ARGS
#
#   -U
#
#       Skip the UNIT tests.
#
#   -I
#
#       Skip the INTEGRATION tests.
#
#   -S <storeBaseOverride>
#
#       Explicitly set the STOREBASE dir to <storeBaseOverride>. This is useful
#       mostly in non-Linux hosts (like macOS) where there might be a mismatch
#       between the actual STOREBASE path and the text of the path shared between
#       the macOS host and the docker VM.
#
#   -r <service>
#
#       Restart <service> in interactive mode. This is mainly for debugging
#       and is typically used to restart the 'pfcon', 'pfioh', and 'pman'
#       services.
#
#   -e <computeEnv>
#
#       Register all plugins to the passed <computeEnv>. Note, this is simply
#       an index string that is actually defined in `pfcon`. In other words,
#       the <computeEnv> here is just a label, and the actual env is fully
#       specified by `pfcon`.
#
#   -a <swarm-advertise-adr>
#
#       If specified, pass <swarm-advertise-adr> to swarm init.
#
#   -i
#
#       Optional do not restart final chris_dev in interactive mode. If any
#       sub services have been restarted in interactive mode then this will
#       break the final restart of the chris_dev container. Thus, if any
#       services have been restarted with '-r <service>' it is recommended
#       to also use this flag to avoid the chris_dev restart.
#
#   -s
#
#       Optional skip intro steps. This skips the check on latest versions
#       of containers and the interval version number printing. Makes for
#       slightly faster startup.
#
#   -p
#
#       Optional pause after instantiating system to allow user to stop
#       and restart services in interactive mode. User stops and restarts
#       services explicitly with
#
#               docker stop <ID> && docker rm -vf <ID> && *make* -r <service>
#
#   [local|fnndsc[:dev]] (optional, default = 'fnndsc')
#
#       If specified, denotes the container "family" to use.
#
#       If a colon suffix exists, then this is interpreted to further
#       specify the TAG, i.e :dev in the example above.
#
#       The 'fnndsc' family are the containers as hosted on docker hub.
#       Using 'fnndsc' will always attempt to pull the latest container first.
#
#       The 'local' family are containers that are assumed built on the local
#       machine and assumed to exist. The 'local' containers are used when
#       the 'pfcon/pman/pfioh/pfurl' services are being locally
#       developed/debugged.
#
#


source ./decorate.sh
source ./cparse.sh

declare -i STEP=0
declare -i b_restart=0
declare -i b_pause=0
declare -i b_skipIntro=0
declare -i b_norestartinteractive_chris_dev=0
declare -i b_debug=0
declare -i b_swarmAdvertiseAdr=0
declare -i b_storeBaseOverride=0
COMPUTEENV="host"
SWARMADVERTISEADDR=""
RESTART=""
HERE=$(pwd)
LINE="------------------------------------------------"
# echo ""
# echo "Starting script in dir $HERE"

CREPO=fnndsc
TAG=:latest

if [[ -f .env ]] ; then
    source .env
fi

while getopts "r:psidUIa:S:e:" opt; do
    case $opt in
        e) COMPUTEENV=$OPTARG                   ;;
        r) b_restart=1
           RESTART=$OPTARG                      ;;
        p) b_pause=1                            ;;
        s) b_skipIntro=1                        ;;
        i) b_norestartinteractive_chris_dev=1   ;;
        a) b_swarmAdvertiseAdr=1
            SWARMADVERTISEADDR=$OPTARG          ;;
        d) b_debug=1                            ;;
        U) b_skipUnitTests=1                    ;;
        I) b_skipIntegrationTests=1             ;;
        S) b_storeBaseOverride=1
           STOREBASE=$OPTARG                    ;;
    esac
done

shift $(($OPTIND - 1))
if (( $# == 1 )) ; then
    REPO=$1
    export CREPO=$(echo $REPO | awk -F \: '{print $1}')
    export TAG=$(echo $REPO | awk -F \: '{print $2}')
    if (( ${#TAG} )) ; then
        TAG=":$TAG"
    fi
fi

declare -a A_CONTAINER=(
    "fnndsc/chris:dev^CHRISREPO"
    "fnndsc/chris_store^STOREREPO"
    "fnndsc/pfcon${TAG}^PFCONREPO"
    "fnndsc/pfurl${TAG}^PFURLREPO"
    "fnndsc/pfioh${TAG}^PFIOHREPO"
    "fnndsc/pman${TAG}^PMANREPO"
    "fnndsc/swarm^SWARMREPO"
    "fnndsc/pfdcm${TAG}^PFDCMREPO"
    "fnndsc/docker-swift-onlyone^SWIFTREPO"
)

title -d 1 "Setting global exports..."
    if (( ! b_storeBaseOverride )) ; then
        if [[ ! -d FS/remote ]] ; then
            mkdir -p FS/remote
        fi
        cd FS/remote
        STOREBASE=$(pwd)
        cd $HERE
    fi
    echo -e "${STEP}.1 For pman override to swarm containers, exporting\nSTOREBASE=$STOREBASE " | ./boxes.sh
    export STOREBASE=$STOREBASE
    if (( b_debug )) ; then
        echo -e "${STEP}.2 Setting debug quiet to OFF. Note this is noisy!" | ./boxes.sh
        export CHRIS_DEBUG_QUIET=0
    fi
windowBottom

if (( b_restart )) ; then
    title -d 1 "Restarting ${RESTART} service"                          \
                    "in interactive mode..."
    printf "${LightCyan}%40s${LightGreen}%40s\n"                        \
                "Stopping" "${RESTART}_service"                         | ./boxes.sh
    windowBottom

    docker-compose --no-ansi -f docker-compose_dev.yml stop ${RESTART}_service >& dc.out > /dev/null
    echo -en "\033[2A\033[2K"
    cat dc.out | ./boxes.sh

    printf "${LightCyan}%40s${LightGreen}%40s\n"                        \
                "rm -f" "${RESTART}_service"                            | ./boxes.sh
    windowBottom

    docker-compose --no-ansi -f docker-compose_dev.yml rm -f ${RESTART}_service >& dc.out > /dev/null
    echo -en "\033[2A\033[2K"
    cat dc.out | ./boxes.sh
    windowBottom

    docker-compose -f docker-compose_dev.yml run --service-ports        \
        ${RESTART}_service
else
    title -d 1 "Pulling non-'local/' core containers where needed..."   \
                "and creating appropriate .env for docker-compose"
    docker pull mysql:5         | ./boxes.sh
    docker pull rabbitmq:3      | ./boxes.sh
    if (( ! b_skipIntro )) ; then
        echo "# Variables declared here are available to"               > .env
        echo "# docker-compose on execution"                            >>.env
        for CORE in ${A_CONTAINER[@]} ; do
            cparse $CORE " " "REPO" "CONTAINER" "MMN" "ENV"
            echo "${ENV}=${REPO}"                                       >>.env
            if [[ $REPO != "local" ]] ; then
                echo ""                                                 | ./boxes.sh
                CMD="docker pull ${REPO}/$CONTAINER"
                printf "${LightCyan}%-40s${Green}%40s${Yellow}\n"       \
                            "docker pull" "${REPO}/$CONTAINER"          | ./boxes.sh
                windowBottom
                sleep 1
                echo $CMD | sh                                          | ./boxes.sh -c
            fi
        done
        echo "TAG="                                                     >>.env
    fi
    windowBottom

    if (( ! b_skipIntro )) ; then
        title -d 1 "Will use containers with following version info:"
        for CORE in ${A_CONTAINER[@]} ; do
            cparse $CORE " " "REPO" "CONTAINER" "MMN" "ENV"
            if [[   $CONTAINER != "chris:dev"            && \
                    $CONTAINER != "chris_store"          && \
                    $CONTAINER != "pl-pacsretrieve"      && \
                    $CONTAINER != "pl-pacsquery"         && \
                    $CONTAINER != "docker-swift-onlyone" && \
                    $CONTAINER != "swarm" ]] ; then
                windowBottom
                CMD="docker run ${REPO}/$CONTAINER --version"
                Ver=$(echo $CMD | sh | grep Version)
                echo -en "\033[2A\033[2K"
                printf "${White}%40s${Green}%40s${Yellow}\n"            \
                        "${REPO}/$CONTAINER" "$Ver"                     | ./boxes.sh
            fi
        done
        # Determine the versions of pfurl *inside* pfcon and chris:dev
        windowBottom
        CMD="docker run --entrypoint /usr/local/bin/pfurl ${PFCONREPO}/pfcon${TAG} --version"
        Ver=$(echo $CMD | sh | grep Version)
        echo -en "\033[2A\033[2K"
        printf "${White}%40s${Green}%40s${Yellow}\n"                    \
                    "pfurl inside ${PFCONREPO}/pfcon${TAG}" "$Ver"      | ./boxes.sh
        windowBottom
        CMD="docker run --entrypoint /usr/local/bin/pfurl ${CHRISREPO}/chris:dev --version"
        Ver=$(echo $CMD | sh | grep Version)
        echo -en "\033[2A\033[2K"
        printf "${White}%40s${Green}%40s${Yellow}\n"                    \
                    "pfurl inside ${CHRISREPO}/CUBE" "$Ver"             | ./boxes.sh
        windowBottom
    fi

    title -d 1 "Stopping and restarting the docker swarm... "
        docker swarm leave --force >dc.out 2>dc.out
        cat dc.out | ./boxes.sh
        if (( b_swarmAdvertiseAdr )) ; then
            docker swarm init --advertise-addr=$SWARMADVERTISEADDR      |\
                sed 's/[[:alnum:]]+:/\n&/g' | sed -E 's/(.{80})/\1\n/g' | ./boxes.sh
        else
            docker swarm init --advertise-addr 127.0.0.1                |\
                sed 's/[[:alnum:]]+:/\n&/g' | sed -E 's/(.{80})/\1\n/g' | ./boxes.sh
        fi
        echo "Swarm started"                                            | ./boxes.sh
    windowBottom

    title -d 1 "Shutting down any running CUBE and CUBE related containers... "
        echo "This might take a few minutes... please be patient."              | ./boxes.sh ${Yellow}
        windowBottom
        docker-compose --no-ansi -f docker-compose_dev.yml stop >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | sed -E 's/(.{80})/\1\n/g'                                  | ./boxes.sh ${LightBlue}
        docker-compose --no-ansi -f docker-compose_dev.yml rm -vf >& dc.out > /dev/null
        cat dc.out | sed -E 's/(.{80})/\1\n/g'                                  | ./boxes.sh ${LightCyan}
        for CORE in ${A_CONTAINER[@]} ; do
            cparse $CORE " " "REPO" "CONTAINER" "MMN" "ENV"
            docker ps -a                                                        |\
                grep $CONTAINER                                                 |\
                awk '{printf("docker stop %s && docker rm -vf %s\n", $1, $1);}' |\
                sh >/dev/null                                                   | ./boxes.sh
            printf "${White}%40s${Green}%40s${NC}\n"                            \
                        "$CONTAINER" "stopped"                                  | ./boxes.sh
        done
    windowBottom

    title -d 1 "Changing permissions to 755 on" "$(pwd)"
        cd $HERE
        echo "chmod -R 755 $(pwd)"                                      | ./boxes.sh
        chmod -R 755 $(pwd)
    windowBottom

    title -d 1 "Checking that FS directory tree is empty..."
        mkdir -p FS/local
        mkdir -p FS/remote
        mkdir -p FS/data
        chmod -R 777 FS
        b_FSOK=1
        type -all tree >/dev/null 2>/dev/null
        if (( ! $? )) ; then
            tree FS                                                     | ./boxes.sh
            report=$(tree FS | tail -n 1)
            if [[ "$report" != "3 directories, 0 files" ]] ; then
                b_FSOK=0
            fi
        else
            report=$(find FS 2>/dev/null)
            lines=$(echo "$report" | wc -l)
            if (( lines != 4 )) ; then
                b_FSOK=0
            fi
        fi
        if (( ! b_FSOK )) ; then
            printf "There should only be 3 directories and no files in the FS tree!\n"  | ./boxes.sh ${Red}
            printf "Please manually clean/delete the entire FS tree and re-run.\n"      | ./boxes.sh ${Yellow}
            printf "\nThis script will now exit with code '1'.\n\n"                     | ./boxes.sh ${Yellow}
            exit 1
        fi
        printf "${LightCyan}%40s${LightGreen}%40s\n"                    \
                    "Tree state" "[ OK ]"                               | ./boxes.sh
    windowBottom

    title -d 1 "Starting CUBE containerized development environment using " "./docker-compose_dev.yml"
        echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
        echo "docker-compose -f docker-compose_dev.yml up -d"           | ./boxes.sh ${LightCyan}
        windowBottom
        docker-compose --no-ansi -f docker-compose_dev.yml up -d        >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | sed -E 's/(.{80})/\1\n/g'                          | ./boxes.sh ${LightGreen}
    windowBottom

    title -d 1 "Pause for manual restart of services?"
    if (( b_pause )) ; then
        echo "Pausing... hit *ANY* key to continue"                     | ./boxes.sh
        windowBottom
        old_stty_cfg=$(stty -g)
        stty raw -echo ; REPLY=$(head -c 1) ; stty $old_stty_cfg
        echo -en "\033[2A\033[2K"
        echo "Resuming..."                                              | ./boxes.sh
    fi
    windowBottom

    title -d 1 "Waiting until ChRIS database server is ready to accept connections..."
        echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
        windowBottom
        docker-compose -f docker-compose_dev.yml        \
            exec chris_dev_db sh -c                     \
            'while ! mysqladmin -uroot -prootp status 2> /dev/null; do sleep 5; done;' >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        sed -E 's/[[:alnum:]]+:/\n&/g' dc.out | ./boxes.sh
        echo "Granting <chris> user all DB permissions...."             | ./boxes.sh ${LightCyan}
        echo "This is required for the Django tests."                   | ./boxes.sh ${LightCyan}
        docker-compose -f docker-compose_dev.yml        \
            exec chris_dev_db mysql -uroot -prootp -e   \
            'GRANT ALL PRIVILEGES ON *.* TO "chris"@"%"' >& dc.out > /dev/null
        cat dc.out                                                      | ./boxes.sh
    windowBottom

    title -d 1 "Waiting until CUBE is ready to accept connections..."
        echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
        windowBottom
        docker-compose --no-ansi -f docker-compose_dev.yml        \
            exec chris_dev sh -c                        \
            'while ! curl -sSf http://localhost:8000/api/v1/users/ 2> /dev/null; do sleep 5; done;' > dc.out
        echo -en "\033[2A\033[2K"
        cat dc.out | python -m json.tool 2>/dev/null                    | ./boxes.sh ${LightGreen}
        echo ""                                                         | ./boxes.sh
        echo "Ready to accept connections"                              | ./boxes.sh ${LightGreen}
        echo ""                                                         | ./boxes.sh
    windowBottom

    if (( ! b_skipUnitTests )) ; then
        title -d 1 "Running CUBE Unit tests..."
        echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
        windowBottom
        docker-compose -f docker-compose_dev.yml    \
            exec chris_dev python manage.py         \
            test --exclude-tag integration
        status=$?
        title -d 1 "CUBE Unit results"
        if (( $status == 0 )) ; then
            printf "%40s${LightGreen}%40s${NC}\n"                       \
                "CUBE Unit tests" "[ success ]"                         | ./boxes.sh
        else
            printf "%40s${Red}%40s${NC}\n"                              \
                "CUBE Unit tests" "[ failure ]"                         | ./boxes.sh
        fi
        windowBottom
    fi

    if (( ! b_skipIntegrationTests )) ; then
        title -d 1 "Running CUBE Integration tests..."
        echo "This might take more than a few minutes... please be patient."    | ./boxes.sh ${Yellow}
        windowBottom
        docker-compose -f docker-compose_dev.yml    \
            exec chris_dev python manage.py         \
            test --tag integration
        status=$?
        title -d 1 "CUBE Integration results"
        if (( $status == 0 )) ; then
            printf "%40s${LightGreen}%40s${NC}\n"                       \
                "CUBE Integration tests" "[ success ]"                  | ./boxes.sh
            echo ""                                                     | ./boxes.sh
            printf "%80s\n" "Clearing internal pman database..."        | ./boxes.sh
            windowBottom
            docker-compose --no-ansi -f docker-compose_dev.yml          \
                exec pman_service pman_do --op DBclean                  >& dc.out >/dev/null
            echo -en "\033[2A\033[2K"
            cat dc.out | sed -E 's/(.{80})/\1\n/g'                      | ./boxes.sh ${LightBlue}
        else
            printf "%40s${Red}%40s${NC}\n"                              \
                "CUBE Integration tests" "[ failure ]"                  | ./boxes.sh
        fi
        windowBottom
    fi

    title -d 1 "Waiting until ChRIS store is ready to accept connections..."
        echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
        windowBottom
        docker-compose -f docker-compose_dev.yml    \
            exec chrisstore sh -c                   \
            'while ! curl -sSf http://localhost:8010/api/v1/users/ 2> /dev/null; do sleep 5; done;' > dc.out
        echo -en "\033[2A\033[2K"
        cat dc.out | python -m json.tool 2>/dev/null                    | ./boxes.sh ${LightGreen}
        echo ""                                                         | ./boxes.sh
        echo "Ready to accept connections"                              | ./boxes.sh ${LightGreen}
        echo ""                                                         | ./boxes.sh
    windowBottom

    title -d 1 "Creating two ChRIS STORE API users"
        echo ""                                                         | ./boxes.sh
        echo "Creating superuser chris:chris1234..."                    | ./boxes.sh
        echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
        windowBottom
        docker-compose -f docker-compose_dev.yml    \
            exec chrisstore /bin/bash -c            \
            'python manage.py createsuperuser --noinput --username chris --email chris@babymri.org 2> /dev/null;' >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out                                                      | ./boxes.sh ${LightGreen}
        windowBottom
        docker-compose -f docker-compose_dev.yml    \
            exec chrisstore /bin/bash -c            \
            'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"chris\"); user.set_password(\"chris1234\"); user.save()"' >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out                                                      | ./boxes.sh ${LightGreen}
        echo ""                                                         | ./boxes.sh
        echo "Creating superuser cubeadmin:cubeadmin1234..."            | ./boxes.sh
        windowBottom
        docker-compose -f docker-compose_dev.yml    \
            exec chrisstore /bin/bash -c            \
            'python manage.py createsuperuser --noinput --username cubeadmin --email cubeadmin@babymri.org 2> /dev/null;' >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out                                                      | ./boxes.sh ${LightGreen}
        windowBottom

        docker-compose -f docker-compose_dev.yml    \
            exec chrisstore /bin/bash -c            \
            'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"cubeadmin\"); user.set_password(\"cubeadmin1234\"); user.save()"' >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out                                                      | ./boxes.sh ${LightGreen}
        echo ""                                                         | ./boxes.sh
        windowBottom
        docker-compose -f docker-compose_dev.yml restart chrisstore     >& dc.out > /dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out                                                      | ./boxes.sh ${LightGreen}
        echo ""                                                         | ./boxes.sh
    windowBottom

    #
    # Array of plugin names to be used in ChRIS.
    #
    # See `cparse.sh` for an explanation of the formatting of elements
    # in the plugin name string.
    #
    declare -a chris_store_plugins=(
                         "pl-simplefsapp"
                         "pl-simpledsapp"
                         "pl-s3retrieve"
                         "pl-s3push"
                         "pl-dircopy"
                         "pl-pfdicom_tagextract::dcm_tagExtract"
                         "pl-pfdicom_tagsub::dcm_tagSub"
                         "pl-pacscopy"
                         "pl-mpcs"
                         "pl-freesurfer_pp"
                         "pl-z2labelmap"
                         "pl-mri10yr06mo01da_normal"
    )

    title -d 1 "Checking on container plugins and pulling latest versions where needed..."
        for plugin in "${chris_store_plugins[@]}" ; do
            cparse $plugin ".py" "REPO" "CONTAINER" "MMN" "ENV"
            if [[ $REPO == "fnndsc" ]] ; then
                printf "${Cyan}%25s${NC}<--${LightBlue}[ dockerhub ]${NC}::${LightGreen}%37s\n" \
                    "[ $CONTAINER ]" "$REPO/$CONTAINER"                 | ./boxes.sh
                windowBottom
                CMD="docker pull $REPO/$CONTAINER"
                echo $CMD | sh                                          | ./boxes.sh -c
                echo ""                                                 | ./boxes.sh
            fi
        done
    windowBottom

    title -d 1 "Automatically uploading some plugins to the ChRIS store..."
        declare -i i=1
        echo ""                                                     | ./boxes.sh
        echo ""                                                     | ./boxes.sh
        for plugin in "${chris_store_plugins[@]}"; do
            cparse $plugin ".py" "REPO" "CONTAINER" "MMN" "ENV"
            CMD="docker run --rm $REPO/$CONTAINER ${MMN} --json 2> /dev/null"
            PLUGIN_REP=$(docker run --rm $REPO/$CONTAINER ${MMN} --json 2> /dev/null)
            # echo "$PLUGIN_REP" | python -m json.tool                    | ./boxes.sh ${LightGreen}
            echo -en "\033[2A\033[2K"
            printf "%8s${Cyan}%28s${NC}%5s${LightBlue}%39s\n" \
              "${STEP}.$i: " "[ $CONTAINER ]" "--->" "[ ChRIS Store ]"   | ./boxes.sh
            windowBottom

            docker-compose -f docker-compose_dev.yml                                \
                exec chrisstore python plugins/services/manager.py add "$CONTAINER" \
                cubeadmin https://github.com/FNNDSC "$REPO/$CONTAINER"              \
                --descriptorstring "$PLUGIN_REP" >& dc.out >/dev/null
            status=$?
            echo -en "\033[2A\033[2K"
            cat dc.out | ./boxes.sh

            if (( $status == 0 )) ; then
                printf "%40s${LightGreen}%40s${NC}\n"                   \
                        "ChRIS store upload" "[ success ]"              | ./boxes.sh
            else
                printf "%40s${Yellow}%40s${NC}\n"                     \
                        "ChRIS store upload" "[ failure ]"              | ./boxes.sh
            fi
            ((i++))
            windowBottom
        done

    title -d 1 "Automatically creating two unlocked pipelines in the ChRIS STORE" \
                            "(unmutable and available to all users)"
        S3_PLUGIN_VER=$(docker run --rm fnndsc/pl-s3retrieve s3retrieve.py --version)
        SIMPLEDS_PLUGIN_VER=$(docker run --rm fnndsc/pl-simpledsapp simpledsapp.py --version)

        PIPELINE_NAME="s3retrieve_v${S3_PLUGIN_VER}-simpledsapp_v${SIMPLEDS_PLUGIN_VER}"
        printf "%20s${LightBlue}%60s${NC}\n"                            \
                    "Creating pipeline..." "[ $PIPELINE_NAME ]"         | ./boxes.sh
        STR1='[{"plugin_name": "pl-s3retrieve", "plugin_version": "'
        STR2='", "plugin_parameter_defaults": [{"name": "bucket", "default": "somebucket"}, {"name": "awssecretkey", "default": "somekey"},
        {"name": "awskeyid", "default": "somekeyid"}], "previous_index": null}, {"plugin_name": "pl-simpledsapp", "plugin_version": "'
        STR3='", "previous_index": 0}]'
        PLUGIN_TREE=${STR1}${S3_PLUGIN_VER}${STR2}${SIMPLEDS_PLUGIN_VER}${STR3}
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chrisstore python pipelines/services/manager.py        \
            add "${PIPELINE_NAME}" cubeadmin "${PLUGIN_TREE}" --unlock

        PIPELINE_NAME="simpledsapp_v${SIMPLEDS_PLUGIN_VER}-simpledsapp_v${SIMPLEDS_PLUGIN_VER}-simpledsapp_v${SIMPLEDS_PLUGIN_VER}"
        echo -en "\033[2A\033[2K"
        printf "%20s${LightBlue}%60s${NC}\n"                            \
                    "Creating pipeline..." "[ $PIPELINE_NAME ]"         | ./boxes.sh
        STR4='[{"plugin_name": "pl-simpledsapp", "plugin_version": "'
        STR5='", "previous_index": null},{"plugin_name": "pl-simpledsapp", "plugin_version": "'
        STR6='", "previous_index": 0},{"plugin_name": "pl-simpledsapp", "plugin_version": "'
        STR7='", "previous_index": 0}]'
        PLUGIN_TREE=${STR4}${SIMPLEDS_PLUGIN_VER}${STR5}${SIMPLEDS_PLUGIN_VER}${STR6}${SIMPLEDS_PLUGIN_VER}${STR7}
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chrisstore python pipelines/services/manager.py        \
            add "${PIPELINE_NAME}" cubeadmin "${PLUGIN_TREE}" --unlock
        echo -en "\033[2A\033[2K"
    windowBottom

    #
    # Array of plugin names to be pulled from the Store and
    # used in ChRIS, including an optional remote computing env
    # designation ([^<env>]).
    #
    # See `cparse.sh` for an explanation of the formatting of elements
    # in the plugin name string.
    declare -a chris_plugins=(
                         "pl-simplefsapp"
                         "pl-simplefsapp^moc"
                         "pl-simpledsapp"
                         "pl-simpledsapp^moc"
                         "pl-s3retrieve"
                         "pl-s3push"
                         "pl-dircopy"
                         "pl-pfdicom_tagextract"
                         "pl-pfdicom_tagsub"
                         "pl-pacscopy"
                         "pl-mpcs"
                         "pl-mpcs^moc"
                         "pl-freesurfer_pp"
                         "pl-freesurfer_pp^moc"
                         "pl-z2labelmap"
                         "pl-z2labelmap^moc"
                         "pl-mri10yr06mo01da_normal"
                         "pl-mri10yr06mo01da_normal^moc"
    )

    title -d 1 "Automatically registering some plugins from the ChRIS store into CUBE..."
        declare -i i=1
        echo ""                                                     | ./boxes.sh
        echo ""                                                     | ./boxes.sh
        for plugin in "${chris_plugins[@]}"; do
            cparse $plugin ".py" "REPO" "CONTAINER" "MMN" "ENV"
            echo -en "\033[2A\033[2K"
            printf "%8s${LightBlue}%15s${NC}%2s${Cyan}%-30s${Yellow}%5s${LightGreen}%8s${NC}%2s${Cyan}%10s\n" \
                "${STEP}.$i:" "[ ChRIS Store ]" "::" "[ $CONTAINER ]"   \
                "--->" "[ CUBE ]" "::" "$ENV"                           | ./boxes.sh
            windowBottom

            computeDescription="${ENV} description"
            docker-compose -f docker-compose_dev.yml                    \
                exec chris_dev python plugins/services/manager.py       \
                add "$ENV" "$ENV Description"
            docker-compose -f docker-compose_dev.yml                    \
                exec chris_dev python plugins/services/manager.py       \
                register $ENV --pluginname "$CONTAINER"
            status=$?
            echo -en "\033[2A\033[2K"

            if (( $status == 0 )) ; then
                printf "%40s${LightGreen}%40s${NC}\n"                   \
                    "CUBE registation" "[ success ]"                    | ./boxes.sh
            else
                printf "%40s${Yellow}%40s${NC}\n"                     \
                    "CUBE registration" "[ failure ]"                   | ./boxes.sh
            fi
            ((i++))
            windowBottom
        done

    title -d 1 "Creating two ChRIS API users"
        echo "Setting superuser chris:chris1234..."                     | ./boxes.sh
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chris_dev /bin/bash -c                                 \
            'python manage.py createsuperuser --noinput --username chris --email dev@babymri.org 2> /dev/null;' >& dc.out >/dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | ./boxes.sh

        echo "Saving superuser chris:chris1234..."                      | ./boxes.sh
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chris_dev /bin/bash -c \
            'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"chris\"); user.set_password(\"chris1234\"); user.save()"' >& dc.out >/dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | ./boxes.sh

        echo ""                                                         | ./boxes.sh
        echo "Setting superuser user cube:cube1234..."                  | ./boxes.sh
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chris_dev /bin/bash -c                                 \
            'python manage.py createsuperuser --noinput --username cube --email dev@babymri.org 2> /dev/null;' >& dc.out >/dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | ./boxes.sh

        echo "Saving superuser user cube:cube1234..."                   | ./boxes.sh
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chris_dev /bin/bash -c                                 \
            'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"cube\"); user.set_password(\"cube1234\"); user.save()"' >& dc.out >/dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | ./boxes.sh
    windowBottom

    title -d 1 "Automatically creating a locked pipeline in CUBE"       \
            "(mutable by the owner and not available to other users)"
        PIPELINE_NAME="s3retrieve_v${S3_PLUGIN_VER}-simpledsapp_v${SIMPLEDS_PLUGIN_VER}_1"
        printf "%20s${LightBlue}%60s${NC}\n"                            \
                    "Creating pipeline..." "[ $PIPELINE_NAME ]"         | ./boxes.sh
        PLUGIN_TREE=${STR1}${S3_PLUGIN_VER}${STR2}${SIMPLEDS_PLUGIN_VER}${STR3}
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chris_dev                                              \
            python pipelines/services/manager.py add "${PIPELINE_NAME}" cube "${PLUGIN_TREE}" >& dc.out >/dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | ./boxes.sh
    windowBottom

    title -d 1 "Automatically creating an unlocked pipeline in CUBE" "(unmutable and available to all users)"
        PIPELINE_NAME="simpledsapp_v${SIMPLEDS_PLUGIN_VER}-simpledsapp_v${SIMPLEDS_PLUGIN_VER}-simpledsapp_v${SIMPLEDS_PLUGIN_VER}"
        printf "%20s${LightBlue}%60s${NC}\n"                            \
                    "Creating pipeline..." "[ $PIPELINE_NAME ]"         | ./boxes.sh
        PLUGIN_TREE=${STR4}${SIMPLEDS_PLUGIN_VER}${STR5}${SIMPLEDS_PLUGIN_VER}${STR6}${SIMPLEDS_PLUGIN_VER}${STR7}
        windowBottom
        docker-compose -f docker-compose_dev.yml                        \
            exec chris_dev                                              \
            python pipelines/services/manager.py add "${PIPELINE_NAME}" cube "${PLUGIN_TREE}" --unlock >& dc.out >/dev/null
        echo -en "\033[2A\033[2K"
        cat dc.out | ./boxes.sh
   windowBottom

    if (( !  b_norestartinteractive_chris_dev )) ; then
        title -d 1 "Restarting CUBE's Django development server"        \
                            "in interactive mode..."
            printf "${LightCyan}%40s${LightGreen}%40s\n"                \
                        "Stopping" "pman_service"                       | ./boxes.sh
            windowBottom
            docker-compose --no-ansi -f docker-compose_dev.yml stop pman_service >& dc.out > /dev/null
            echo -en "\033[2A\033[2K"
            cat dc.out | ./boxes.sh

            printf "${LightCyan}%40s${LightGreen}%40s\n"                \
                        "rm -f" "pman_service"                          | ./boxes.sh
            windowBottom
            docker-compose --no-ansi -f docker-compose_dev.yml rm -f pman_service >& dc.out > /dev/null
            echo -en "\033[2A\033[2K"
            cat dc.out | ./boxes.sh

            printf "${LightCyan}%40s${LightGreen}%40s\n"                \
                        "Stopping" "chris_dev"                          | ./boxes.sh
            windowBottom
            docker-compose --no-ansi -f docker-compose_dev.yml stop chris_dev >& dc.out >/dev/null
            echo -en "\033[2A\033[2K"
            cat dc.out | ./boxes.sh


            printf "${LightCyan}%40s${LightGreen}%40s\n"                \
                        "rm -f" "chris_dev"                             | ./boxes.sh
            windowBottom
            docker-compose --no-ansi -f docker-compose_dev.yml rm -f chris_dev >& dc.out >/dev/null
            echo -en "\033[2A\033[2K"
            cat dc.out | ./boxes.sh

            printf "${LightCyan}%40s${LightGreen}%40s\n"                \
                        "Starting in interactive mode" "chris_dev"      | ./boxes.sh
            windowBottom
            docker-compose -f docker-compose_dev.yml run --service-ports chris_dev
    else
        title -d 1 "Restarting CUBE's Django development server"        \
                            "in non-interactive mode..."
            printf "${LightCyan}%40s${LightGreen}%40s\n"                \
                        "Restarting" "chris_dev"                        | ./boxes.sh
            windowBottom
            docker-compose -f docker-compose_dev.yml restart chris_dev
    fi
fi
