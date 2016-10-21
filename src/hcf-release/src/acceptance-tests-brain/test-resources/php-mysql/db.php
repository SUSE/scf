<!--
/**
* Copyright 2015 IBM Corp. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the “License”);
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* https://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an “AS IS” BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
-->

<?php

if(!$_ENV["VCAP_SERVICES"]){ //local dev
    $mysql_server_name = "127.0.0.1:3306";
    $mysql_username = "root";
    $mysql_password = "";
    $mysql_database = "test";
} else { //running in Bluemix
    $vcap_services = json_decode($_ENV["VCAP_SERVICES"]);

    $db="";
    foreach ($vcap_services as $key => $v){
      $db=$v[0]->credentials;
    }

    $mysql_database = $db->database;
    $mysql_port=$db->port;
    $mysql_server_name =$db->hostname . ':' . $db->port;
    $mysql_username = $db->username; 
    $mysql_password = $db->password;
}
//echo "Debug: " . $mysql_server_name . " " .  $mysql_username . " " .  $mysql_password . "\n";

$mysqli = new mysqli($mysql_server_name, $mysql_username, $mysql_password, $mysql_database);
if ($mysqli->connect_errno) {
    echo "Failed to connect to MySQL: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
    die();
}

?>
