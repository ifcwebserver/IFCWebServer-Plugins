###require 'spreadsheet'
###require "fileutils"
require $root_dir + '/conf.rb'
require $root_dir + '/ifc_functions.rb'
require $root_dir + '/extensions/Server.rb'
require $root_dir + '/db_function.rb'
#methods
def load_schema_and_extensions
	require $root_dir + '/onFly.rb'	
	require $root_dir + '/extensions/Server.rb'
end

def as_XML
	$output_format="to_xml"
end

def as_HTML
	$output_format="to_html"
end

def load_classes(cls,save_to_file=false)
	load_ifc_classes(cls,save_to_file)
end

def load_psets(f)
  if File.exists?("cache/dm/" + f + "/psets_per_class.hash")
   data=open("cache/dm/" + f + "/psets_per_class.hash", "rb") {|io| io.read }
   $psets = Marshal.load(data)        
  end
end


def use(f)
  load_schema_and_extensions
  ###FakeFS.deactivate!
  $ifcObjects={}
  $guid = {}
  $points={}
  $hash={}
  $parent={}	
  $log={}
  $saved_as_ifc={}
  $depend_on={}
  $ifc_file_name= f
  read_ifc_file(f)
  ###FakeFS.activate! #if $cgi.remote_addr != "127.0.0.1" and $cgi.remote_addr != ""
end


$debug_time =""
$log={}
$res = Array.new(10, 0)
$header_done=true
$auto_forward = true
$ifc_header="ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('IFC WebServer 1.10',''),'2;1');
FILE_NAME('','',(''),(''),'','','');
FILE_SCHEMA(('IFC2X3'));
ENDSEC;

DATA;"
$output_format = "to_html" 					
$auto_to_svg=false 							
$auto_to_dae=false 							
$dae_single_file=false 						
$ifcUnit={}
$ifcUnit["Length"]=1
$ifcObjects={}
$guid = {}
$points={}
$hash={}
$parent={}	
$num_of_objects={}
$report_cols=""

$filter=""
$errorFile= File.new($root_dir + "/log/Errors.log",  "w")



#load_schema_and_extensions
original_stdout = $stdout

$stdout = File.open($root_dir + "/cache/"  + $username + "/#{$ifc_file_name}/cobie.html", "wb")
$ifc_model = $ifc_file_name

print <<XX
<html>
<head>
<meta name="robots" content="noindex" >
<meta name="robots" content="nofollow">
<link rel="stylesheet" type="text/css" href="/style.css">
<script type='text/javascript' src='/js/common.js'></script>
<script type='text/javascript' src='/js/css.js'></script>
<script type='text/javascript' src='/js/standardista-table-sorting.js'></script>
<script type='text/javascript' src='/js/dtree.js'></script>
<style>
body {font-family: "Lato", sans-serif;}

/* Style the tab */
div.tab {
    overflow: hidden;
    border: 1px solid #ccc;
    background-color: #f1f1f1;
}

/* Style the buttons inside the tab */
div.tab button {
    background-color: inherit;
    float: left;
    border: none;
    outline: none;
    cursor: pointer;
    padding: 14px 16px;
    transition: 0.3s;
    font-size: 17px;
}

/* Change background color of buttons on hover */
div.tab button:hover {
    background-color: #ddd;
}

/* Create an active/current tablink class */
div.tab button.active {
    background-color: #ccc;
}

/* Style the tab content */
.tabcontent {
    display: none;
    padding: 6px 12px;
    border: 1px solid #ccc;
    border-top: none;
}
</style>
</head>
<body>
<script>
function openTab(evt, tabName) {
    var i, tabcontent, tablinks;
    tabcontent = document.getElementsByClassName("tabcontent");
    for (i = 0; i < tabcontent.length; i++) {
        tabcontent[i].style.display = "none";
    }
    tablinks = document.getElementsByClassName("tablinks");
    for (i = 0; i < tablinks.length; i++) {
        tablinks[i].className = tablinks[i].className.replace(" active", "");
    }
    document.getElementById(tabName).style.display = "block";
    evt.currentTarget.className += " active";
}
</script>
XX


####require 'fakefs/safe'
####FakeFS.activate! #if $cgi.remote_addr != "127.0.0.1" and $cgi.remote_addr != "141.30.165.52"


#4653
#http://docs.buildingsmartalliance.org/MVD_COBIE/
load_schema_and_extensions
use $ifc_model
$created_on = get_header_info($ifc_model).time_stamp
$created_by= "ifcwebserver@gmail.com"
  
#create a hash index for space classification, it will be used for the description column
$classification={}
$space_classification={}
$zone_classification={}
$space_classification_name={}
$contained_in={}
IFCRELASSOCIATESCLASSIFICATION.where("all" ,"o").each { |classification_rel|
classification_rel.relatedObjects.toIfcObject.each { |kk,vv|
$space_classification[vv.line_id] = classification_rel.relatingClassification.to_obj.itemReference if vv.class == IFCSPACE
$zone_classification[vv.line_id] = classification_rel.relatingClassification.to_obj.name if vv.class == IFCZONE
if vv.class == IFCSPACE
    $space_classification_name[vv.line_id] = classification_rel.relatingClassification.to_obj.name
else
    $classification[vv.line_id] = classification_rel.relatingClassification.to_obj.name
end
}
}
#create a hash index for space container, it will be used for the FloorName column
$space_parent={}
IFCRELAGGREGATES.where("all" ,"o").each { |aggregate_rel|
aggregate_rel.relatedObjects.toIfcObject.each { |kk,vv|
$space_parent[vv.line_id]= aggregate_rel.relatingObject.to_obj.name if vv.class == IFCSPACE
}
}
  
IFCRELCONTAINEDINSPATIALSTRUCTURE.where("all" ,"o").each { |contained_in_rel|
parent_name=  contained_in_rel.relatingStructure.to_obj.name
contained_in_rel.relatedElements.toIfcObject.each { |kk,vv| 
$contained_in[vv.line_id] =parent_name
}
}
  
#COBie methods
    def add_cell(value,color)
        puts "<td style='background-color:" + color + "'>" + value.to_s.gsub("'","") + "</td>"
    end
  
    def get_created_on(o)
       #if o.ownerHistory.to_obj.creationDate != "0"
           $created_on
    end
  
    def get_created_by(o)
        #s.ownerHistory.to_obj.owningUser.to_obj.thePerson.to_obj.id ##123321
        $created_by
    end
  
class Cobie
    color_required = "#FFFF9C"
    color_reference= "#FFCB9C"
    color_external_reference ="#CE9AFF"
    color_specified_as_required ="#CEFFCE"
    color_gray = "#BDBEBD" #Secondary information when preparing product data
    color_blue ="#9CCBFF" #Regional, owner, or product-specific data
      
    def self.cobie_contact
        puts '<div id="Contact" class="tabcontent">'
        HTML.h1 "Contact"
        HTML.tableHeader "Email","CreatedBy","CreatedOn","Category","Company","Phone","ExternalSystem","ExternalObject","ExternalIdentifier","Department","OrganizationCode","GivenName","FamilyName","Street","PostalBox","Town","StateRegion","PostalCode","Country"
        IFCPERSONANDORGANIZATION.where("all","o").each { |o|
        begin
        row={}
        org=nil
        p=nil
        org=o.theOrganization.to_obj
        if org != nil
            if  org.addresses.to_obj.class == IFCTELECOMADDRESS
                row["Email"] = org.addresses.to_obj.electronicMailAddresses
                row["Phone"] = org.addresses.to_obj.telephoneNumbers
            else
                row["Email"] = "n/a"
                row["Phone"] = "n/a"
            end
          row["CreatedBy"] = ""
          row["CreatedOn"] = get_created_on(org)
        if org.roles.to_obj != nil
          row["Category"] = org.roles.to_obj.userDefinedRole 
        else
          row["Category"] = "n/a"
        end
            row["Company"] = org.name
            row["ExternalSystem"] = "n/a"
            row["ExternalObject"] = "n/a"
            row["ExternalIdentifier"] = "n/a"
            row["Department"] = org.description
            row["OrganizationCode"] = org.id
        else
        end
        p=o.thePerson.to_obj
        if p != nil
          row["GivenName"] = p.givenName
          row["FamilyName"] = p.familyName
          if p.addresses.to_obj.class == IFCPOSTALADDRESS
              adress=p.addresses.to_obj
              row["Street"]=adress.addressLines
              row["PostalBox"]=adress.postalBox
              row["Town"]=""
              row["StateRegion"]=adress.region
              row["PostalCode"]=adress.postalCode
              row["Country"]=adress.country  
          end
        else
        end
        puts "<tr>"
        add_cell row["Email"],"#FFFF9C "
        add_cell row["CreatedBy"],"#FFCB9C"
        add_cell row["CreatedOn"],"#FFFF9C "
        add_cell row["Category"],"#FFCB9C"
        add_cell row["Company"],"#FFFF9C "
        add_cell row["Phone"],"#FFFF9C "
        add_cell row["ExternalSystem"],"#CE9AFF"
        add_cell row["ExternalObject"],"#CE9AFF"
        add_cell row["ExternalIdentifier"],"#CE9AFF"
        add_cell row["Department"],"#CEFFCE"
        add_cell row["OrganizationCode"],"#CEFFCE"
        add_cell row["GivenName"] ,"#CEFFCE"
        add_cell row["FamilyName"] ,"#CEFFCE"
        add_cell row["Street"],"#CEFFCE"
        add_cell row["PostalBox"],"#CEFFCE"
        add_cell row["Town"],"#CEFFCE"
        add_cell row["StateRegion"],"#CEFFCE"
        add_cell row["PostalCode"],"#CEFFCE"
        add_cell row["Country"],"#CEFFCE"  
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
    def self.cobie_facility
        puts '<div id="Facility" class="tabcontent">'
        HTML.h1 "Facility"
        HTML.tableHeader "ID","Name","CreatedBy","CreatedOn","Category","ProjectName","SiteName","LinearUnits","AreaUnits","VolumeUnits","CurrencyUnit","AreaMeasurement","ExternalSystem","ExternalProjectObject","ExternalProjectIdentifier","ExternalSiteObject","ExternalSiteIdentifier","ExternalFacilityObject","ExternalFacilityIdentifier","Description","ProjectDescription","SiteDescription","Phase"
        IFCPROJECT.where("all","o").each_with_index { |o,id|
        begin
        puts "<tr>"
        puts "<th>#{id + 1}</th>"
        add_cell o.name, "#FFFF9C "
        add_cell get_created_by(o), "#FFCB9C"
        add_cell get_created_on(o), "#FFFF9C "
        #Category
        add_cell "", "#FFCB9C"
        #ProjectName
        add_cell IFCRELAGGREGATES.where("o.relatedObjects.include?(\"#" + o.line_id.to_s + "\")" ,"o.relatingObject.to_obj.name").join, "#FFFF9C "
        #SiteName
        add_cell o.name, "#FFFF9C "
        #LinearUnits
        add_cell "", "#FFCB9C"
        #AreaUnits
        add_cell "", "#FFCB9C"
        #VolumeUnits
        add_cell "", "#FFCB9C"
        #CurrencyUnit
        add_cell "", "#FFCB9C"
        #AreaMeasurement
        add_cell "", "#FFCB9C"
        #ExternalSystem
        add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#FFCB9C"
        #ExternalProjectObject
        add_cell "", "#FFCB9C"
        #ExternalProjectIdentifier
        add_cell o.globalId, "#FFCB9C"
        #ExternalFacilityObject
        add_cell "", "#FFCB9C"
        #ExternalFacilityIdentifier
        add_cell "", "#FFFF9C "
        #Description
        add_cell "", "#CE9AFF"
        #ProjectDescription
        add_cell "", "#CE9AFF"
        #SiteDescription
        add_cell "", "#CE9AFF"
        #Phase
        add_cell o.phase, "#CEFFCE"
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
    def self.cobie_floor
        puts '<div id="Floor" class="tabcontent">'
        HTML.h1 "Floor"
        HTML.tableHeader "Name","CreatedBy","CreatedOn","Category","ExtSystem","ExtObject","ExtIdentifier","Description","Elevation","Height"
        IFCBUILDINGSTOREY.where("all","o").each { |o|
        begin
        puts "<tr>"
        add_cell o.name, "#FFFF9C "
        add_cell get_created_by(o), "#FFCB9C"
        add_cell get_created_on(o), "#FFFF9C "
        add_cell $classification[o.line_id], "#FFCB9C"
        add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#FFCB9C"
        add_cell $ifcClassesNames[o.class.to_s], "#CE9AFF"
        add_cell o.globalId, "#CE9AFF"
        add_cell o.description, "#CEFFCE"
        add_cell o.elevation, "#CEFFCE"
        add_cell "", "#CEFFCE"
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
    def self.cobie_space
        puts '<div id="Space" class="tabcontent">'
        HTML.h1 "Space"
        HTML.tableHeader "ID","Name","CreatedBy","CreatedOn","Category","FloorName","Description","ExtSystem","ExtObject","ExtIdentifier","RoomTag","UsableHeight","GrossArea","NetArea"
        IFCSPACE.where("all","o").each_with_index { |s,id|
        begin
        puts "<tr>"
        puts "<th>#{id + 1}</th>"
        #Name
        add_cell s.name + "(" + s.longName + ")", "#FFFF9C "
        add_cell get_created_by(s), "#FFFF9C "
        add_cell get_created_on(s), "#FFCB9C"
          
        #Category
        add_cell $space_classification[s.line_id].to_s + ":" + $space_classification_name[s.line_id].to_s, "#FFFF9C "
        #FloorName
        add_cell $space_parent[s.line_id].to_s, "#FFCB9C"
        #add_cell s.description, "#FFFF9C "
        add_cell $space_classification_name[s.line_id].to_s, "#FFFF9C "
        add_cell s.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#CE9AFF"
        add_cell $ifcClassesNames[s.class.to_s], "#CE9AFF"
        add_cell s.globalId, "#CE9AFF"
        #RoomTag
        add_cell s.longName, "#CEFFCE"
          
        #UsableHeight
        add_cell run_sql($username,$ifc_model,"select PropertyValue  from 'Properties' where STEP_ID = #{s.line_id} and PropertyName = 'Height'"), "#CEFFCE"
        #GrossArea
        add_cell run_sql($username,$ifc_model,"select PropertyValue  from 'Properties' where STEP_ID = #{s.line_id} and PropertyName = 'GrossFloorArea'"), "#CEFFCE"
        #NetArea
        add_cell run_sql($username,$ifc_model,"select PropertyValue  from 'Properties' where STEP_ID = #{s.line_id} and PropertyName = 'NetFloorArea'"), "#CEFFCE"
         rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
    def self.cobie_zone
        puts '<div id="Zone" class="tabcontent">'
        HTML.h1 "Zone"
        HTML.tableHeader "Name","CreatedBy","CreatedOn","Category","SpaceNames","ExtSystem","ExtObject","ExtIdentifier","Description"
        IFCZONE.where("all","o").each { |z|
        begin
        puts "<tr>"
        add_cell z.name, "#FFFF9C "
        add_cell get_created_by(z), "#FFCB9C"
        add_cell get_created_on(z), "#FFFF9C "
        add_cell $zone_classification[z.line_id], "#FFCB9C"
        add_cell IFCRELASSIGNSTOGROUP.where("o.relatingGroup.to_obj.line_id ==" + z.line_id.to_s,"o.relatedObjects").join.toIfcObject.values.map { |s| s.name}.join("<br>"),"#FFCB9C"
        add_cell z.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#FFCB9C"
        add_cell $ifcClassesNames[z.class.to_s], "#CE9AFF"
        add_cell z.globalId, "#CE9AFF"
        add_cell z.description, "#FFFF9C "
      
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
    def self.cobie_type
        puts '<div id="Type" class="tabcontent">'
        HTML.h1 "Type"
        HTML.tableHeader "ID","Name","CreatedBy","CreatedOn","Category","Description","AssetType","Manufacturer","ModelNumber","WarrantyGuarantorParts","WarrantyDurationParts","WarrantyGuarantorLabor","WarrantyDurationLabor","WarrantyDurationUnit","ExtSystem","ExtObject","ExtIdentifier","ReplacementCost","ExpectedLife","DurationUnit","WarrantyDescription","NominalLength","NominalWidth","NominalHeight","ModelReference","Shape","Size","Color","Finish","Grade","Material","Constituents","Features","AccessibilityPerformance","CodePerformance","SustainabilityPerformance"
        IFCELEMENTTYPE.where("all","o").each_with_index { |o,id|
        begin
        puts "<tr>"
        puts "<th>#{id + 1}</th>"
        add_cell o.name, "#FFFF9C "
        add_cell o.ownerHistory.to_obj.owningUser.to_obj.thePerson.to_obj.id, "#FFCB9C"
        add_cell get_created_on(o), "#FFFF9C "
        add_cell $classification[o.line_id], "#FFCB9C"
        add_cell o.description, "#FFFF9C "
        add_cell "","#FFCB9C"
        add_cell "","#FFCB9C"
        add_cell "","#FFFF9C "
        add_cell "","#FFCB9C"
        add_cell "","#FFFF9C "
        add_cell "","#FFCB9C"
        add_cell "","#FFFF9C "
        add_cell "","#FFCB9C"
        add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#CE9AFF"
        add_cell $ifcClassesNames[o.class.to_s], "#CE9AFF"
        add_cell o.globalId, "#CE9AFF"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#FFCB9C"
        add_cell "","#CEFFCE"
        add_cell "","#FFCB9C"
        add_cell "","#FFFF9C "
        add_cell "","#FFFF9C "
        add_cell "","#FFFF9C "
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "","#CEFFCE"
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
      
    def self.cobie_component
        puts '<div id="Component" class="tabcontent">'
        HTML.h1 "Component"
        HTML.tableHeader "ID","Name","CreatedBy","CreatedOn","TypeName","Space","Description","ExtSystem","ExtObject","ExtIdentifier","SerialNumber","InstallationDate","WarrantyStartDate","TagNumber","BarCode","AssetIdentifier","Area","Length"
        components=[]
        IFCDOOR.where("all","o").each { |o| components << o }
        IFCWINDOW.where("all","o").each { |o|   components << o }
        IFCFURNISHINGELEMENT.where("all","o").each { |o|    components << o }
        IFCFLOWTERMINAL.where("all","o").each { |o| components << o }
        components.each_with_index {  |o,id|
        begin
        puts "<tr>"
        puts "<th>#{id + 1}</th>"
        add_cell o.name, "#FFFF9C"
        add_cell get_created_by(o), "#FFCB9C"
        add_cell get_created_on(o), "#FFFF9C "
        add_cell o.objectType  , "#FFCB9C"
        add_cell $contained_in[o.line_id].to_s,"#FFCB9C"
        add_cell o.description,"#FFFF9C"
        add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#CE9AFF"
        add_cell $ifcClassesNames[o.class.to_s], "#CE9AFF"
        add_cell "<a href='http://ifcwebserver.org/ifc.rb?ifc_file=#{$ifc_model}&q=$#{o.line_id}'>#{o.globalId}</a><a href='/bim-annotator/?url=../temp/#{$username}/#{$ifc_model}/#{o.line_id}.dae&user_id=#{$username}&model=#{$ifc_model.sub(".ifc","")}'></br><img width=80 border='1' src='/temp/#{$username}/#{$ifc_model}/#{o.line_id}.png' /></a>", "#CE9AFF"
        add_cell "", "#CEFFCE"
        add_cell "", "#CEFFCE"
        add_cell "", "#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "", "#CEFFCE"
        add_cell "", "#CEFFCE"
        add_cell "","#CEFFCE"
        add_cell "", "#CEFFCE"
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
      
    def self.cobie_system
        HTML.h1 "System"
        HTML.tableHeader "Name","CreatedBy","CreatedOn","Category","ComponentNames","ExtSystem","ExtObject","ExtIdentifier","Description"
        IFCSYSTEM.where("all","o").each { |o|
        begin
        puts "<tr>"
        add_cell o.name, "#FFFF9C "
        add_cell o.ownerHistory.to_obj.owningUser.to_obj.thePerson.to_obj.id, "#FFCB9C"
        add_cell get_created_on(o), "#FFFF9C "
        add_cell $classification[o.line_id], "#FFCB9C"
        add_cell IFCRELASSIGNSTOGROUP.where("o.relatingGroup.to_obj.line_id ==" + o.line_id.to_s,"o.relatedObjects").join.toIfcObject.values.map { |s| s.name}.join("<br>"),"#FFCB9C"
        add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#FFCB9C"
        add_cell $ifcClassesNames[o.class.to_s], "#CE9AFF"
        add_cell o.globalId, "#CE9AFF"
        add_cell o.description, "#FFFF9C "
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table><hr>"
    end
      
    def self.cobie_assembly
        HTML.h1 "Assembly"
        HTML.tableHeader "Name","CreatedBy","CreatedOn","SheetName","ParentName","ChildNames","AssemblyType","ExtSystem","ExtObject","ExtIdentifier","Description"
        IFCRELPROJECTSELEMENT.where("all","o").each { |o|
        puts "<tr>"
        add_cell o.name, "#FFFF9C "
        add_cell o.ownerHistory.to_obj.owningUser.to_obj.thePerson.to_obj.id, "#FFCB9C"
        add_cell get_created_on(o), "#FFFF9C "
        add_cell $ifcClassesNames[o.relatingElement.to_obj.class.to_s], "#FFCB9C"
        add_cell o.relatingElement.to_obj.as_link, "#FFCB9C"
        add_cell o.relatedFeatureElement,"#FFCB9C"
        add_cell "","#FFCB9C"
        add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#CE9AFF"
        add_cell $ifcClassesNames[o.class.to_s],"#FFCB9C"
        add_cell o.globalId, "#CE9AFF"
        add_cell o.description, "#CEFFCE"
        puts "</tr>"
        }
        puts "</table><hr>"
    end
      
    def self.cobie_document
        puts '<div id="Document" class="tabcontent">'
        HTML.h1 "Document"
        HTML.tableHeader "Name","CreatedBy","CreatedOn","Category","ApprovalBy","Stage","SheetName","RowName","Directory","File","ExtSystem","ExtObject","ExtIdentifier","Description","Reference"
        IFCRELASSOCIATESDOCUMENT.where("all","o").each { |o|
        begin
        puts "<tr>"
        add_cell o.name, "#FFFF9C "
        add_cell o.ownerHistory.to_obj.owningUser.to_obj.thePerson.to_obj.id, "#FFCB9C"
        add_cell get_created_on(o), "#FFFF9C "
        add_cell o.relatingDocument.to_obj.purpose, "#FFCB9C"
        add_cell o.relatingDocument.to_obj.documentOwner.to_obj.thePerson.to_obj.id,"#FFCB9C"
        add_cell o.relatingDocument.to_obj.intendedUse,"#FFCB9C"
        add_cell "","#FFCB9C"
        add_cell "","#FFCB9C"
        add_cell o.relatingDocument.to_obj.location,"#FFFF9C "
        add_cell o.relatingDocument.to_obj.name,"#FFFF9C "
        add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#CE9AFF"
        add_cell o.relatedObjects, "#CE9AFF"
        add_cell o.globalId, "#CE9AFF"
        add_cell o.description, "#CEFFCE"
        add_cell o.relatingDocument.to_obj.documentId, "#CEFFCE"
        rescue Exception => e
          puts e.message  
          puts e.backtrace.inspect
        end
        puts "</tr>"
        }
        puts "</table>"
        puts "</div>"
    end
      
    def self.cobie_attribute
        HTML.h1 "Attribute"
        HTML.tableHeader "ID","Name","CreatedBy","CreatedOn","Category","SheetName","RowName","Value","Unit","ExtSystem","ExtObject","ExtIdentifier","Description","AllowedValues"
        IFCPROPERTYSET.where("all","o").each_with_index { |o,id|
        o.hasProperties.to_s.toIfcObject.each do |k,v|
            if v.class == IFCPROPERTYSINGLEVALUE and v.nominalValue != "$"
             begin
            puts "<tr>"
            add_cell id, "#FFFFFF"
            add_cell v.name, "#FFFF9C "
            add_cell o.ownerHistory.to_obj.owningUser.to_obj.thePerson.to_obj.id, "#FFCB9C"
            add_cell get_created_on(o), "#FFFF9C "
            add_cell $classification[o.line_id], "#FFCB9C"
            add_cell "", "#FFCB9C"
            add_cell "", "#FFCB9C"
            add_cell v.valid_value, "#FFFF9C "
            add_cell v.unit, "#FFFF9C "
            add_cell o.ownerHistory.to_obj.owningApplication.to_obj.applicationFullName, "#FFCB9C"
            add_cell o.name, "#CE9AFF"
            add_cell o.globalId, "#CE9AFF"
            add_cell v.description, "#CEFFCE"
            add_cell "", "#CEFFCE"
            rescue Exception => e
              puts e.message  
              puts e.backtrace.inspect
            end
            puts "</tr>"
            end
        end
        }
        puts "</table><hr>"
    end
  
    def self.cobie_spare
        HTML.h1 "Spare"
    end
      
    def self.cobie_resource
        HTML.h1 "Resource"
    end
      
    def self.cobie_job
        HTML.h1 "Job"
    end
      
    def self.cobie_impact
        HTML.h1 "Impact"
    end
      
    def self.cobie_coordinate
        HTML.h1 "Coordinate"
    end
      
    def self.cobie_connection
        HTML.h1 "Connection"
    end
      
    def self.cobie_issue
        HTML.h1 "Issue"
    end
  
end
#TODO: ["System","Assembly","Connection","Spare","Resource","Job","Impact",,"Attribute","Coordinate","Issue","PickLists"]
puts "<div class='tab'>"
["Instruction","Contact","Facility","Floor",
"Space","Zone","Type","Component","Document"].each { |tab_name|
puts "<button class='tablinks' onclick=\"openTab(event, '#{tab_name}')\">#{tab_name}</button>"
}
puts "</div>"
Cobie.cobie_contact
Cobie.cobie_facility
Cobie.cobie_floor
Cobie.cobie_space
Cobie.cobie_zone
Cobie.cobie_type
Cobie.cobie_component
Cobie.cobie_document
$stdout = original_stdout
puts "<hr><a href='/cache/#{$username}/#{$ifc_file_name}/cobie.html'> IFC--> COBie report</a><hr>"