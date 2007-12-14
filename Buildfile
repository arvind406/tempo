$LOAD_PATH.unshift "#{ENV['HOME']}/svn/buildr-trunk/lib/"

require "rubygems"
require "buildr"


# Keep this structure to allow the build system to update version numbers.
VERSION_NUMBER = "5.1.0.3-SNAPSHOT"
NEXT_VERSION = "5.1.0.4"

require "dependencies.rb"
require "repositories.rb"
# leave this require after dependencies.rb so the same jpa version is used throughout the whole build
require "tasks/openjpa"
require "tasks/xmlbeans" 

desc "Tempo Workflow"
define "tempo" do
  project.version = VERSION_NUMBER
  project.group = "org.intalio.tempo"

  compile.options.source = "1.5"
  compile.options.target = "1.5"

  desc "Deployment API"
  define "deploy-api" do
    compile.with SERVLET_API, SLF4J, SPRING
    package :jar
  end  
  
  desc "Form Dispatcher Servlet"
  define "fds" do
    libs = [AXIS2, COMMONS, SLF4J, LOG4J, SERVLET_API, STAX_API, DOM4J, JAXEN, COMMONS]
    compile.with libs 
    resources.filter.using "version" => VERSION_NUMBER
    test.with libs, XMLUNIT
    package(:war).with :libs => libs
  end  


  desc "Workflow Processes"
  define "processes" do
    define "xpath-extensions" do
      package(:jar)
    end
    
    define "AbsenceRequest" do
      package(:jar)
    end
    
    define "TaskManager" do
      package(:jar)
    end
    
    define "Store" do
      package(:jar)
    end
    
    define "peopleActivity" do
      package(:jar)
    end
  end
  

  desc "Security Framework"
  define "security" do
    compile.with COMMONS, CASTOR, LOG4J, SLF4J, SPRING, XERCES

    test.exclude "*BaseSuite"
    test.exclude "*FuncTestSuite"
    test.exclude "*ldap*"

    package :jar
  end
  
  desc "Security Web-Service Common Library"
  define "security-ws-common" do
    compile.with project("security"), 
                 AXIOM, AXIS2, SLF4J, STAX_API, SPRING
    package(:jar)
  end
  
  desc "Security Web-Service Client"
  define "security-ws-client" do
    compile.with projects("security", "security-ws-common"), 
                 AXIOM, AXIS2, SLF4J, STAX_API, SPRING
    test.with project("security-ws-common"), COMMONS, CASTOR, LOG4J, XERCES, WS_COMMONS_SCHEMA, WSDL4J, WOODSTOX, SUNMAIL

    # Remember to set JAVA_OPTIONS before starting Jetty
    # export JAVA_OPTIONS=-Dorg.intalio.tempo.configDirectory=/home/boisvert/svn/tempo/security-ws2/src/test/resources
    
    # require live Axis2 instance
    if ENV["LIVE"] == 'yes'
      LIVE_ENDPOINT = "http://localhost:8080/axis2/services/TokenService"
    end
    
    if defined? LIVE_ENDPOINT
      test.using :properties => 
        { "org.intalio.tempo.security.ws.endpoint" => LIVE_ENDPOINT,
          "org.intalio.tempo.configDirectory" => _("src/test/resources") }
    end

    package(:jar).tap do |jar|
      jar.with :meta_inf => project("security-ws-service").path_to("src/main/axis2/*.wsdl")
    end
  end

  
  desc "Security Web-Service"
  define "security-ws-service" do
    compile.with projects("security", "security-ws-common"),
                 AXIOM, AXIS2, SLF4J, SPRING, STAX_API  
    package(:aar).with :libs => [ projects("security", "security-ws-common"), CASTOR, LOG4J, SLF4J, SPRING ]
  end
  
  desc "Task Attachment Service Common"
  define "tas-common" do
    compile.with projects("security", "security-ws-client"), 
                 AXIOM, AXIS2, COMMONS, JUNIT, SLF4J, LOG4J, STAX_API, JAXEN

    test.with SUNMAIL, SLF4J, WSDL4J, WS_COMMONS_SCHEMA, WOODSTOX
    test.exclude '*TestUtils*'

    # require live Axis2 instance
    unless ENV["LIVE"] == 'yes'
      test.exclude '*Axis2TASService*'
      test.exclude '*WDSStorageTest*'
    end

    package(:jar)
  end

  desc "Task Attachment Service"
  define "tas-service" do
    package(:aar).with(:libs => [ 
        projects("security", "security-ws-client", "security-ws-common", "tas-common", "web-nutsNbolts"), JAXEN, SPRING, AXIS2, SLF4J, LOG4J])
  end

  desc "Xml Beans generation"
  define "tms-axis" do
    compile_xml_beans "tms-axis/src/main/axis2"
    package(:jar)
  end
  
  desc "Task Management Services Common Library"
  define "tms-common" do
    compile.with projects("security", "security-ws-client", "tms-axis"),AXIOM, SLF4J, SPRING, STAX_API, APACHE_JPA, XERCES, LOG4J, XMLBEANS
    compile { open_jpa_enhance }    
    package(:jar)
    test.with project("tms-axis"), SLF4J, WOODSTOX, APACHE_JPA, SLF4J, LOG4J, APACHE_JPA, XERCES, DOM4J, XMLBEANS
    test.exclude '*TestUtils*'
  end
  
  desc "Task Management Service Client"
  define "tms-client" do
    compile.with projects("tms-axis", "tms-common"), AXIOM, AXIS2, COMMONS, LOG4J, SLF4J, STAX_API, WS_COMMONS_SCHEMA, WSDL4J, APACHE_JPA, XMLBEANS

    test.with projects("tms-axis", "tms-common"), SLF4J, WOODSTOX, XMLBEANS, SUNMAIL
    test.exclude '*TestUtils*'

    unless ENV["LIVE"] == 'yes'
      test.exclude '*RemoteTMSClientTest*'
    end
    package(:jar)
  end
  
  desc "Task Management Service"
  define "tms-service" do
    compile.with projects("security", "security-ws-client", "tms-common", "tms-axis", "tms-client", "web-nutsNbolts"),
                 AXIOM, AXIS2, COMMONS, SLF4J, LOG4J, SPRING, STAX_API, APACHE_JPA, XMLBEANS

    test.with projects("tms-common", "tms-axis"), SUNMAIL, SLF4J, SPRING, WS_COMMONS_SCHEMA, WSDL4J, WOODSTOX, CASTOR, XERCES

    test.using :properties => 
      { "org.intalio.tempo.configDirectory" => _("src/test/resources") }

    # require live Axis2 instance
    unless ENV["LIVE"] == 'yes'
      test.exclude '*TMSAxis2RemoteTest*'
      test.exclude '*RemoteReassginTaskTest*'
      test.exclude "*ReassignTaskLiveTest*"
    end
    test.exclude '*TestUtils*'

    
    package(:aar).with :libs => 
        [ projects("security", "security-ws-client", "tms-axis", "security-ws-common", "tms-common", "web-nutsNbolts"), LOG4J, SLF4J, SPRING, APACHE_JPA ] 
  end
  
  desc "User-Interface Framework"
  define "ui-fw" do
    libs = projects("security", "security-ws-client", "security-ws-common",
                    "tms-axis", "tms-client", "tms-common", "web-nutsNbolts"),
           AXIOM, AXIS2, COMMONS, DOM4J, INTALIO_STATS, JSP_API, JSTL,
           LOG4J, SPRING, SERVLET_API, SLF4J, STAX_API, TAGLIBS, WOODSTOX, 
           WS_COMMONS_SCHEMA, WSDL4J, XERCES, XMLBEANS, APACHE_JPA, JSON, PLUTO
    compile.with libs

    dojo = unzip(path_to(compile.target, "dojo") => download(artifact(DOJO)=>DOJO_URL))
    dojo.from_path(DOJO_WIDGET_BASE).include("*").exclude("demos/*", "release/*", "tests/*", "README", "*.txt")

    build dojo
    resources.filter.using "version" => VERSION_NUMBER
    package(:war).with(:libs=>libs).
      include("src/main/config/geronimo/1.0/*", path_to(compile.target, "dojo"))
  end
  
  define "ui-pluto" do
    package(:war)
  end
  
  desc "Workflow Deployment Service Client"
  define "wds-client" do
    compile.with ANT, COMMONS, JARGS, JUNIT, LOG4J, SLF4J
    package(:jar) 
  end

  desc "Workflow Deployment Service"
  define "wds-service" do
    libs = [ project("web-nutsNbolts"), COMMONS, LOG4J, SERVLET_API, SPRING, XERCES, APACHE_JPA, SLF4J ]
    compile.with libs
    compile { open_jpa_enhance }    
    resources.filter.using "version" => VERSION_NUMBER
    package(:war).with :libs=>libs
  end

  define "web-nutsNbolts" do
    compile.with project("security"), COMMONS, INTALIO_STATS, JSP_API, LOG4J, SERVLET_API, SLF4J, SPRING, AXIS2
    package :jar
  end
  
  desc "XForms Manager"
  define "xforms-manager" do
    resources.filter.using "version" => VERSION_NUMBER
    package(:war).with :libs=> ORBEON_LIBS
  end
  
end
