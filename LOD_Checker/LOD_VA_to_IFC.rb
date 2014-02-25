module LOD_VA_to_IFC
  #Mapping the LOD attributes in the VA Object/Element Matrix to IFC schema
  def faciltyID;  evaluate self.containedInStructure['line_id'].to_obj.isDecomposedBy['line_id'].to_obj.name  end
  def facilityName; evaluate self.containedInStructure['line_id'].to_obj.isDecomposedBy['line_id'].to_obj.longName  end
  def facilityDescription;  evaluate self.containedInStructure['line_id'].to_obj.isDecomposedBy['line_id'].to_obj.description end
  def storyNumber; evaluate self.containedInStructure['line_id'].to_obj.name end  
  def floorID; evaluate self.containedInStructure['line_id'].to_obj.name end
  def floorName;  evaluate self.containedInStructure['line_id'].to_obj.longName end
  def floorDescription;  evaluate self.containedInStructure['line_id'].to_obj.description end
  def floorElevation; evaluate self.containedInStructure['line_id'].to_obj.elevation end
  def componentID;  evaluate self.tag end
  def componentName;  evaluate self.name end
  def componentDescription;   evaluate self.description end 
  
  def evaluate(value)    
    if value == nil or value.to_s == "$" or  value.to_s == ""  or  value.to_s == "''"      
      "<font color='red'>X</font>"
    else        
      return value 
   end
  end
end

class IFCELEMENT
 include LOD_VA_to_IFC
end