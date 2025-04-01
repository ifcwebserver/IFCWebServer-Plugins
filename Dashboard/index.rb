#! /usr/local/bin/ruby
require '/var/www/html/conf.rb'
require $root_dir + '/login.rb' 
require $root_dir + '/ifc_functions.rb'
require $root_dir + '/HTML.rb'
$bLoaded = false
require $root_dir + "/extensions/Server.rb"
require $root_dir + "/ruby_meta.rb"
require 'yaml'
$cgi = Console.session.cgi if Console.session.cgi != nil
$username = Console.session.username
$username=$cgi['username'] if $cgi['username'] != ""
puts $cgi.header
require 'cgi_exception' if $cgi.remote_addr == "127.0.0.1"
params = $cgi.params
require "sqlite3"
$BIM=$cgi['ifc_file']
print <<EOF
<html>
<head>
<link rel="stylesheet" type="text/css" href="/style.css">
EOF
puts "<title>" + $BIM.to_s + "</title>"
print <<EOF
<script src="/js/prototype.js" type="text/javascript"></script>
<script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<link rel="stylesheet" type="text/css" href="/style.css">
</head>
<body>
<a href="index.rb"><img border=0 src="/img/logo.png" ></a>
<div id="top-menu">
<a href='/index.rb'>Home</a>
</div>
EOF
puts "<form action='index.rb' method='GET'>"
HTML.h4 "Select IFC model:"
HTML.select_box "ifc_file",[""] + Dir.glob("../ifc_files/" + $username  + "/*.ifc").join(",").gsub("../ifc_files/" + $username  + "/","").split(","),[],false,"onchange=\"this.form.submit();\""," style='width:300px'"
puts "</form>"

def load_schema_and_extensions
	require $root_dir + '/onFly.rb'
	Dir["/extensions/byclass/*.rb"].each {|file| load file }
end

def use(f)
	$ifc_file_name= f
	load_schema_and_extensions
	read_ifc_file(f)
	$bLoaded= true
end

def run_sql(user,model,sql)  
  $values=[]
  $keys=[]
  db = SQLite3::Database.new $cache_folder + "/" + user + "/" + model + "/json.sqlite"
  db.results_as_hash = true
  db.execute(sql ) do |row|
    $values << row['value']	
	if  row['key']
		$keys << "'" + row['key'] + "'"
	else
		$keys << "'N/A'" 
	end
  end 
end

if $BIM != ""

#------------------------------------------IfcClasses_Count----------------------------------------------	
	values=[];values << ""
	labels=[];labels << ""
	Server.classes_list($BIM).each { |k,v|
	next if k == "IFC"
	labels << k.sub("Ifc","") + "(" + v.to_s + ")"	
	values << k
	}	
	load "/var/www/html/cache/#{$username}/#{$BIM}/list_of_objects.rb"
	keys =[]
	keys <<  $list_of_objects.map { |key, value| "'" +  key  + "'"} 
	puts "<div id='IfcClasses'></div>
	<script>
	var layout = { title: {text: 'IfcClasses Count'},  height: 400,  width: 800,  showlegend: true};
	var ifcClasses_data = [{
	values:[" +  $list_of_objects.values.join(",") + "],labels: [" + keys.join(",") + "],type: 'pie', textinfo: 'none'}];
	plot = Plotly.newPlot('IfcClasses', ifcClasses_data, layout);	
	plot.update_traces(textinfo='none')
	</script>"
#------------------------------------------Total_Spaces_Count----------------------------------------------
	use $BIM if not $bLoaded
	spaces ={}
	IFCSPACE.where("all","o").each { |s|
	s.longName = "'Not Defined'" if s.longName == '$'
	if s.longName.to_s != ""
		spaces[s.longName] = 0 if spaces[s.longName] == nil
		spaces[s.longName] += 1	
	end
	}
	keys=spaces.keys.map { |key, value|   key  } 
	values= spaces.values
	puts "<div id='Spaces'></div>
	<script>
	var layout = { title: {text: 'Space name'}, height: 400,  width: 800,  showlegend: true , uniformtext_mode: 'hide'};
	var spaces_data = [{
	values:[" +  values.join(",") + "],labels: [" + keys.join(",") + "],type: 'pie', textinfo: 'none'}];
	Plotly.newPlot('Spaces', spaces_data, layout);	
	</script>"	
#------------------------------------------Total_Spaces_Areas----------------------------------------------	
	sql= "SELECT   SUM(    CAST(
      (
        SELECT json_extract(attr_gfa.value, '$.PropertyValue')
        FROM json_each(Properties.attributes) AS attr_gfa
        WHERE json_extract(attr_gfa.value, '$.PropertyName') = 'GrossFloorArea'
        LIMIT 1  -- Ensure only one value per row (adjust if multiple entries are allowed)
      ) AS REAL
    )
  ) AS value ,
  (SELECT json_extract(attr_SpaceUsageCode.value, '$.PropertyValue')
        FROM json_each(Properties.attributes) AS attr_SpaceUsageCode
        WHERE json_extract(attr_SpaceUsageCode.value, '$.PropertyName') = 'UnitUsageDescription') as key  
        FROM Properties where    PropertyValue = 'IfcSpace'  group by key order by value;"
	 run_sql($username,$BIM,sql)	 
	 puts "<div id='Total_Spaces_Areas'></div>
	<script>
	var layout = { title: {text: 'Total Space Areas (m2)'}, height: 400,  width: 800,  showlegend: true};
	var total_Spaces_Areas_data = [{
	y:[" +  $values.join(",") + "],x: [" + $keys.join(",") + "],type: 'bar'}];
	Plotly.newPlot('Total_Spaces_Areas', total_Spaces_Areas_data, layout);	
	</script>"
#-----------------------------------Total_Zone_Areas--------------------------------------------------------	
	sql= "SELECT   SUM(    CAST(
      (
        SELECT json_extract(attr_gfa.value, '$.PropertyValue')
        FROM json_each(Properties.attributes) AS attr_gfa
        WHERE json_extract(attr_gfa.value, '$.PropertyName') = 'GrossFloorArea'
        LIMIT 1  -- Ensure only one value per row (adjust if multiple entries are allowed)
      ) AS REAL
    )
  ) AS value ,
  (SELECT json_extract(attr_SpaceUsageCode.value, '$.PropertyValue')
        FROM json_each(Properties.attributes) AS attr_SpaceUsageCode
        WHERE json_extract(attr_SpaceUsageCode.value, '$.PropertyName') = 'ZoneObjectType') as key  
        FROM Properties where    PropertyValue = 'IfcSpace'  group by key order by value;"
run_sql($username,$BIM,sql)	 
	 puts "<div id='Total_Zone_Areas'></div>
	<script>
	var layout = {  title: {text: 'Total Zones Areas (m2)'}, height: 400,  width: 800,  showlegend: true};
	var total_Zone_Areas_data = [{
	y:[" +  $values.join(",") + "],x: [" + $keys.join(",") + "],type: 'bar'}];
	Plotly.newPlot('Total_Zone_Areas', total_Zone_Areas_data, layout);	
	</script>"	
#------------------------TotalBuildupArea_per_BuildingStorey---------------------------------------------------------	
	sql="SELECT   (    CAST(
      (
        SELECT json_extract(attr_TotalBuildupArea.value, '$.PropertyValue')
        FROM json_each(Properties.attributes) AS attr_TotalBuildupArea
        WHERE json_extract(attr_TotalBuildupArea.value, '$.PropertyName') = 'TotalBuildupArea'
        LIMIT 1  -- Ensure only one value per row (adjust if multiple entries are allowed)
      ) AS REAL
    )
  ) AS value ,
  (SELECT json_extract(attr_BuildingStoreyName.value, '$.PropertyValue')
        FROM json_each(Properties.attributes) AS attr_BuildingStoreyName
        WHERE json_extract(attr_BuildingStoreyName.value, '$.PropertyName') = 'Name') as key  
        FROM Properties where    PropertyValue = 'IfcBuildingStorey'  group by key order by value;"
		run_sql($username,$BIM,sql)	
		puts "<div id='TotalBuildupArea_per_BuildingStorey'></div>
	<script>
	var layout = { title: {text: 'Total BuildupArea per BuildingStorey (m2)'}, height: 400,  width: 800,  showlegend: true};
	var total_BuildupArea_per_BuildingStorey_data = [{
	y:[" +  $values.join(",") + "],x: [" + $keys.join(",") + "],type: 'bar'}];
	Plotly.newPlot('TotalBuildupArea_per_BuildingStorey', total_BuildupArea_per_BuildingStorey_data, layout);	
	</script>"
#--------------------------------------------------------------------------------------------------------------------
end