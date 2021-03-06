*** Settings ***
Documentation     Test suite to deploy devstack with networking-odl
Suite Setup       Devstack Suite Setup
Library           SSHLibrary
Library           OperatingSystem
Library           RequestsLibrary
Resource          ../../../libraries/Utils.robot
Resource          ../../../libraries/OpenStackOperations.robot
Resource          ../../../libraries/DevstackUtils.robot

*** Variables ***
@{NETWORKS_NAME}    net1_network    net2_network
@{SUBNETS_NAME}    subnet1    subnet2
@{NET_1_VM_INSTANCES}    MyFirstInstance_1    MySecondInstance_1
@{NET_2_VM_INSTANCES}    MyFirstInstance_2    MySecondInstance_2
@{VM_IPS}         10.0.0.3    20.0.0.3
@{GATEWAY_IPS}    10.0.0.1    20.0.0.1
@{DHCP_IPS}       10.0.0.2    20.0.0.2
@{SUBNETS_RANGE}    10.0.0.0/24    20.0.0.0/24

*** Test Cases ***
Run Devstack Gate Wrapper
    Write Commands Until Prompt    unset GIT_BASE
    Write Commands Until Prompt    env
    ${output}=    Write Commands Until Prompt    ./devstack-gate/devstack-vm-gate-wrap.sh    timeout=3600s    #60min
    Log    ${output}
    Should Not Contain    ${output}    ERROR: the main setup script run by this job failed
    # workaround for https://bugs.launchpad.net/networking-odl/+bug/1512418
    Write Commands Until Prompt    cd /opt/stack/new/tempest-lib
    Write Commands Until Prompt    sudo python setup.py install
    [Teardown]    Show Devstack Debugs

Validate Neutron and Networking-ODL Versions
    ${output}=    Write Commands Until Prompt    cd /opt/stack/new/neutron; git branch;
    Should Contain    ${output}    * ${OPENSTACK_BRANCH}
    ${output}=    Write Commands Until Prompt    cd /opt/stack/new/networking-odl; git branch;
    Should Contain    ${output}    * ${NETWORKING-ODL_BRANCH}

tempest.api.network
    Run Tempest Tests    ${TEST_NAME}

Create Networks
    [Documentation]    Create Network with neutron request.
    : FOR    ${NetworkElement}    IN    @{NETWORKS_NAME}
    \    Create Network    ${NetworkElement}

Create Subnets For net1_network
    [Documentation]    Create Sub Nets for the Networks with neutron request.
    Create SubNet    net1_network    subnet1    @{SUBNETS_RANGE}[0]

Create Subnets For net2_network
    [Documentation]    Create Sub Nets for the Networks with neutron request.
    Create SubNet    net2_network    subnet2    @{SUBNETS_RANGE}[1]

List Ports
    ${output}=    Write Commands Until Prompt    neutron -v port-list
    Log    ${output}

List Available Networks
    ${output}=    Write Commands Until Prompt    neutron -v net-list
    Log    ${output}

List Tenants
    ${output}=    Write Commands Until Prompt    keystone tenant-list
    Log    ${output}

List Nova
    ${output}=    Write Commands Until Prompt    nova list
    Log    ${output}

List Nova Images
    ${output}=    Write Commands Until Prompt    nova image-list
    Log    ${output}

List Nova Flavor
    ${output}=    Write Commands Until Prompt    nova flavor-list
    Log    ${output}

Create Vm Instances For net1_network
    [Documentation]    Create Vm instances using flavor and image names.
    Create Vm Instances    net1_network    ${NET_1_VM_INSTANCES}
    [Teardown]    Show Debugs    ${NET_1_VM_INSTANCES}

Create Vm Instances For net2_network
    [Documentation]    Create Vm instances using flavor and image names.
    Create Vm Instances    net2_network    ${NET_2_VM_INSTANCES}
    [Teardown]    Show Debugs    ${NET_2_VM_INSTANCES}

Verify Created Vm Instance In Dump Flow
    [Documentation]    Verify the existence of the created vm instance ips in the dump flow.
    ${output}=    Write Commands Until Prompt    sudo ovs-ofctl -O OpenFlow13 dump-flows br-int
    Log    ${output}
    : FOR    ${VmIpElement}    IN    @{VM_IPS}
    \    Should Contain    ${output}    ${VmIpElement}

Create Routers
    [Documentation]    Create Router and Add Interface to the subnets.
    Create Router    router_1

Verify Gateway Ip After Interface Added
    [Documentation]    Verify the existence of the gateway ips with the dump flow in Beryllium.
    Run Keyword If    "${ODL_VERSION}" == "lithium-latest"    Run Keyword And Ignore Error    Verify Gateway Ips
    ...    ELSE IF    "${ODL_VERSION}" != "lithium-latest"    Verify Gateway Ips

Verify Dhcp Flow Entries
    [Documentation]    Verify Created SubNets for the Networks with the dump flow in Beryllium.
    Run Keyword If    "${ODL_VERSION}" == "lithium-latest"    Run Keyword And Ignore Error    Verify Dhcp Ips
    ...    ELSE IF    "${ODL_VERSION}" != "lithium-latest"    Verify Dhcp Ips

Delete Vm Instances In net1_network
    [Documentation]    Delete Vm instances using instance names in net1_network.
    : FOR    ${VmElement}    IN    @{NET_1_VM_INSTANCES}
    \    Delete Vm Instance    ${VmElement}

Delete Vm Instances In net2_network
    [Documentation]    Delete Vm instances using instance names in net2_network.
    : FOR    ${VmElement}    IN    @{NET_2_VM_INSTANCES}
    \    Delete Vm Instance    ${VmElement}

Verify Deleted Vm Instance Removed In Dump Flow
    [Documentation]    Verify the non-existence of the vm instance ips in the dump flow.
    : FOR    ${VmIpElement}    IN    @{VM_IPS}
    \    ${output}=    Write Commands Until Prompt    sudo ovs-ofctl -O OpenFlow13 dump-flows br-int
    \    Log    ${output}
    \    Should Not Contain    ${output}    ${VmIpElement}

Delete Router Interfaces
    [Documentation]    Remove Interface to the subnets.
    : FOR    ${interface}    IN    @{SUBNETS_NAME}
    \    Remove Interface    router_1    ${interface}

Delete Routers
    [Documentation]    Delete Router and Interface to the subnets.
    Delete Router    router_1

Verify Deleted Routers
    [Documentation]    Verify Deleted Routers for the Networks with dump flow.
    Verify No Gateway Ips

Delete Sub Networks In net1_network
    [Documentation]    Delete Sub Nets for the Networks with neutron request.
    Delete SubNet    subnet1

Delete Sub Networks In net2_network
    [Documentation]    Delete Sub Nets for the Networks with neutron request.
    Delete SubNet    subnet2

Delete Networks
    [Documentation]    Delete Networks with neutron request.
    : FOR    ${NetworkElement}    IN    @{NETWORKS_NAME}
    \    Delete Network    ${NetworkElement}

Verify Deleted Subnets
    [Documentation]    Verify Deleted SubNets for the Networks with dump flow.
    Verify No Dhcp Ips
