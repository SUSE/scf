function procPath(val) { 
  
  values = val.split(':');
  for( v in values){
    values[v] = '<span style="color: #'+Math.floor(Math.random()*16777215).toString(16)+'">'+values[v]+'</span>';
  }
  return values.join('</br>');
}

function procJSON(str) {
  var json = JSON.parse(str);
  var newStr;
  for( key in json){
    //newStr +=  
  }
  return str;
}

function procKey(key, val){

  var key = key.toLowerCase();
  var val = val.replace(/\r/g, '').replace(/\n/g, '<br/>');
  var knownKeys = {
    'path': procPath,
    'vmc_app_instance': procJSON
  }

  if(knownKeys[key]) {
    return knownKeys[key](val);
  }else{
    return val;
  }

}

exports.procKey = procKey;
