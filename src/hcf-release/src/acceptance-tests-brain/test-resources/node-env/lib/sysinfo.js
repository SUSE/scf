var os = require('os');

function bytesToSize(bytes) {
    var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return 'n/a';
    var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
    return Math.round(bytes / Math.pow(1024, i), 2) + ' ' + sizes[i];
};

function secondsToTime(secs)
{
    var hours = Math.floor(secs / (60 * 60));
   
    var divisor_for_minutes = secs % (60 * 60);
    var minutes = Math.floor(divisor_for_minutes / 60);
 
    var divisor_for_seconds = divisor_for_minutes % 60;
    var seconds = Math.ceil(divisor_for_seconds);
   
    return hours + " hours, " + minutes + " minutes, " + seconds + " seconds";
}

function sysInfo() {
  
  var properties = [];
  properties.push( ['Platform', os.platform() + ' ' + os.arch()] );
  properties.push( ['Hostname', os.hostname()] );
  properties.push( ['Uptime', secondsToTime(os.uptime())] );
  properties.push( ['Load average', os.loadavg()] );
  properties.push( ['Free memory', bytesToSize(os.freemem()) +  ' / ' + bytesToSize(os.totalmem()) ] );

  return properties;  
}

exports.sysInfo = sysInfo;