//http://updates.html5rocks.com/2012/06/How-to-convert-ArrayBuffer-to-and-from-String
function ab2str(buf) {
  return String.fromCharCode.apply(null, new Uint16Array(buf));
}

function str2ab(str) {
  var buf = new ArrayBuffer(str.length*2); // 2 bytes for each char
  var bufView = new Uint16Array(buf);
  for (var i=0, strLen=str.length; i<strLen; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}



/**
 * GDG namespace
 */
var gdg = gdg || {};
/**
 * GDG examples namespace
 */
gdg.examples = gdg.examples || {};
/**
 * GDG sockets tcp connector app
 */
gdg.examples.tcp = gdg.examples.tcp || {};
/**
 * Socket used by this app.
 */
gdg.examples.tcp.socketId = null;
/**
 * Initialize the app. Handle button clicks etc.
 */
gdg.examples.tcp.init = function(){
  document.querySelector('#connectButton').addEventListener('click', gdg.examples.tcp._handleConnectClick);
  chrome.sockets.tcp.onReceive.addListener(gdg.examples.tcp._onReceive);
  chrome.sockets.tcp.onReceiveError.addListener(gdg.examples.tcp._onReceiveError);
}
gdg.examples.tcp.setStatus = function(status, error){
  var statusElement = document.querySelector('#status');
  statusElement.innerText = status;
  if(error){
    statusElement.classList.add('error');
  } else {
    statusElement.classList.remove('error');
  }
}

gdg.examples.tcp._handleConnectClick = function(e){
  e.target.disabled = true;
  if(gdg.examples.tcp.socketId !== null){
    gdg.examples.tcp._disconnect();
  } else {
    gdg.examples.tcp._connect();
  }
}
/**
 * Connect to the selected socket.
 */
gdg.examples.tcp._connect = function(){
  gdg.examples.tcp.setStatus('');
  var connectionAddr = document.querySelector('#connectionAddr');
  if(!connectionAddr) throw Error("Address field no longer available");
  
  var addr = connectionAddr.value;
  //should be address with port like xx.xx.xx.xx:xxxx
  //Validation is not included here because error will be thrown by sockets API
  //if address has wrong format.
  var pos = addr.indexOf(':');
  if(pos === -1){
    gdg.examples.tcp.setStatus('You must provide port number.', true);
    throw Error("You must provide port number.");
  }
  
  var ip = addr.substr(0,pos);
  var port = parseInt(addr.substr(pos+1));
  
  console.log('Connecting to remote machine at IP: %s on port: %d', ip, port);
  
  gdg.examples.tcp.setStatus('Connecting...');
  chrome.sockets.tcp.create({}, function(createInfo){
    gdg.examples.tcp.socketId = createInfo.socketId;
    chrome.sockets.tcp.connect(createInfo.socketId, ip, port, function(result){
      if(result < 0){
        gdg.examples.tcp.setStatus('Unable connect to remote address', true);
        chrome.sockets.tcp.close(gdg.examples.tcp.socketId);
        gdg.examples.tcp.socketId = null;
        gdg.examples.tcp._disconnected();
        throw Error("Unable to connect to the remote machine.");
      }
      gdg.examples.tcp._connected();
    });
  });
}
/**
 * Function called when succesfully connected
 */
gdg.examples.tcp._connected = function(){
  console.log('Connected!');
  document.querySelector('#connectButton').disabled = false;
  document.querySelector('#connectButton').innerText = 'Disconnect';
  gdg.examples.tcp.setStatus('Connected');
}
/**
 * Disconnect from remote machine and release socket.
 */
gdg.examples.tcp._disconnect = function(){
  gdg.examples.tcp.setStatus('Disconnecting...');
  chrome.sockets.tcp.disconnect(gdg.examples.tcp.socketId, function(){
    chrome.sockets.tcp.close(gdg.examples.tcp.socketId, function(){
      gdg.examples.tcp.setStatus('Not connected');
      gdg.examples.tcp._disconnected();
      gdg.examples.tcp.socketId = null;
    });
  });
}
/**
 * Function called when disconneced from remote host.
 */
gdg.examples.tcp._disconnected = function(){
  document.querySelector('#connectButton').disabled = false;
  document.querySelector('#connectButton').innerText = 'Connect';
}

gdg.examples.tcp._onReceive = function(info){
  if(info.socketId !== gdg.examples.tcp.socketId){
    return; // Some other connection.
  }
  var data = info.data; //ArrayBuffer with a maxium size of bufferSize.
  console.log('Data received from socket.', ab2str(data)w);
}
gdg.examples.tcp._onReceiveError = function(info){
  if(info.socketId !== gdg.examples.tcp.socketId){
    return; // Some other connection.
  }
  var code = info.resultCode; 
  console.error('socket error with code:', code);
}
gdg.examples.tcp.init();