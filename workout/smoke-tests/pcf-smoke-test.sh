#!/bin/bash
set -e
export TERM=xterm

#sample apps
mkdir onetime-directory
cd onetime-directory
git clone https://github.com/vponnam/spring-music.git
cd spring-music
./gradlew assemble
cd ..
git clone https://github.com/vponnam/rabbitmq-cloudfoundry-samples.git
cd rabbitmq-cloudfoundry-samples/spring/
mvn package
cd ../../
git clone https://github.com/vponnam/traveler.git
cd traveler
./gradlew build
cd ..
git clone https://github.com/vponnam/cf-redis-example-app.git
dir=`pwd`
#environment specs
rmq1="https://pivotal-rabbitmq.$sys"
p1=$dir/spring-music/
p2=$dir/traveler/agency/
p3=$dir/traveler/company/
p4=$dir/cook/
p5=$dir/cf-redis-example-app/
p6=$dir/rabbitmq-cloudfoundry-samples/spring/
# Increase push count for load testing
push=1
if [ $push -ge 1 ]
then
cf login -a https://api.$sys -u $user -p $pwd -o $org -s $sn --skip-ssl-validation
#app push
for (( p=1; p<=$push; p++ ))
do
  echo "Push" $p cf t -o $org -s $sn
  cd $p1
  cf push
  sleep 2
  cd $p2
  cf push
  sleep 2
  cd $p3
  cf push
  sleep 2
  cd $p5
  cf p --no-start
done
fi

#mysql on-demand service tests
echo "Started testing MySQL Service"
i3=msql
cf cs p.mysql 1g-dev $i3
until [ `cf service $i3 | grep -c "progress"` -eq 0 ]; do echo -n "*"
done
if [[ `cf service $i3 | grep -c "failed"` -eq 1 ]]; then printf "\noops..! failed creating mysql service instance\n"; exit 1;
fi
if [[ `cf service $i3 | grep -c "succeeded"` -eq 1 ]]; then printf "\nsuccessfully created mysql service instance\n"
cf bs spring-music $i3
cf restage spring-music
printf "\nSuccessfully tested mysql service"
fi

#Rabbitmq service tests
echo "Started testing Rabbitmq service"
if [[ `curl -v $rmq1` && $?=0 ]]; then printf "\nRabbitmq Management console returned response code 200 OK\n";
else printf "\nPlease check Rabbitmq Management console health status\n"
fi
i4=rmq
cf cs p-rabbitmq standard $i4
until [ `cf service $i4 | grep -c "progress"` -eq 0 ]; do echo -n "*"
done
if [[ `cf service $i4 | grep -c "failed"` -eq 1 ]]; then printf "\noops..! failed creating Rabbitmq service instance\n"; exit 1;
fi
if [[ `cf service $i4 | grep -c "succeeded"` -eq 1 ]]; then printf "\nSuccessfully created Rabbitmq service instance\n"
cd $p6
cf p
cf restage rabbitmq-spring
cf rename-service rmq rmq-shared
cf us rabbitmq-spring rmq-shared
printf "\nSuccessfully tested Rabbitmq shared service"
fi

# Test on-demand rabbitmq service
i6=rmq
cf cs p.rabbitmq single-node $i6
until [ `cf service $i6 | grep -c "progress"` -eq 0 ]; do echo -n "*"
done
if [[ `cf service $i6 | grep -c "failed"` -eq 1 ]]; then printf "\noops..! failed creating Rabbitmq service instance\n"; exit 1;
fi
if [[ `cf service $i6 | grep -c "succeeded"` -eq 1 ]]; then printf "\nSuccessfully created Rabbitmq service instance\n"
cd $p6
cf p
cf restage rabbitmq-spring
printf "\nSuccessfully tested Rabbitmq ondemand single-node service"
fi


#spring-cloud-service tests
echo "Started testing spring-cloud-service Service"
i1=smoke-test-cbd
cf cs p-circuit-breaker-dashboard standard $i1
until [ `cf service $i1 | grep -c "progress"` -eq 0 ]; do echo -n "*"
done
if [[ `cf service $i1 | grep -c "failed"` -eq 1 ]]; then printf "\noops..! failed creating circuit-breaker-dashboard service instance\n"; exit 1;
fi
if [[ `cf service $i1 | grep -c "succeeded"` -eq 1 ]]; then printf "\nSuccessfully created circuit-breaker-dashboard service instance\n"
fi
i2=smoke-test-sr
cf cs p-service-registry standard $i2
until [ `cf service $i2 | grep -c "progress"` -eq 0 ]; do echo -n "*"
done
if [[ `cf service $i2 | grep -c "failed"` -eq 1 ]]; then printf "\noops..! failed creating service-registry service instance\n"; exit 1;
fi
if [[ `cf service $i2 | grep -c "succeeded"` -eq 1 ]]; then printf "\nsuccessfully created service-registry service instance\n"
  cf bs agency $i1
  cf bs agency $i2
  cf bs company $i2
  cf restage agency
  cf restage company
fi
i0=smoke-test-cs
cf cs p-config-server standard $i0
until [ `cf service $i0 | grep -c "progress"` -eq 0 ]; do echo -n "*"
done
if [[ `cf service $i0 | grep -c "failed"` -eq 1 ]]; then printf "\noops..! failed creating config-server service instance\n"; exit 1;
fi
if [[ `cf service $i0 | grep -c "succeeded"` -eq 1 ]]; then printf "\nsuccessfully created config-server service instance\n"
  cf service $i0
fi

#Redis tests
printf "\nStarted testing Redis Service"
i5=redis
cf cs p.redis 7gb $i5
until [ `cf service $i5 | grep -c "progress"` -eq 0 ]; do echo -n "*"
done
if [[ `cf service $i5 | grep -c "failed"` -eq 1 ]]; then printf "\noops..! failed creating redis-on-demand service instance\n"; exit 1;
fi
if [[ `cf service $i5 | grep -c "succeeded"` -eq 1 ]]; then printf "\nsuccessfully created redis-on-demand service instance\n"
  cf service $i5
fi
cf bs redis-example-app $i5
cf start redis-example-app
cf app redis-example-app
echo https://$(cf app redis-example-app | grep routes | awk '{print $2}')/foo
curl -kX PUT https://$(cf app redis-example-app | grep routes | awk '{print $2}')/foo -d 'data=bar'
printf "\nInserting data to Redis Cache"
curl -kX GET https://$(cf app redis-example-app | grep routes | awk '{print $2}')/foo
printf "\nRetriving inserted value from Redis Cache\n"
printf "Redis tests are successful\n"


#Clean-up task
printf "\nCleanup task"
cf us agency $i1
cf us agency $i2
cf us company $i2
cf us spring-music $i3
cf us rabbitmq-spring $i6
cf us redis-example-app $i5
cf ds $i0 -f
cf ds $i1 -f
cf ds $i2 -f
cf ds $i3 -f
cf ds rmq-shared -f
cf ds $i6 -f
cf ds $i5 -f

cf d spring-music -r -f
cf d rabbitmq-spring -r -f
cf d agency -r -f
cf d company -r -f
cf d redis-example-app -r -f
cf delete-orphaned-routes -f
printf "\nSucessfully completed Platform smoke-test for all the above services\n"