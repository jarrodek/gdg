library tcpconnector;

import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;

void main() {
  new Tcp();
}

class Tcp {
  int socketId;
  
  Tcp(){
    querySelector('#connectButton').onClick.listen(_handleConnectClick);
    querySelector('#sendButton').onClick.listen(_handleSendClick);
    chrome.sockets.tcp.onReceive.listen(_onReceive);
    chrome.sockets.tcp.onReceiveError.listen(_onReceiveError);
  }
  
  setStatus(String status, [bool error]){
    var statusElement = querySelector('#status');
    statusElement.text = status;
    if (error) {
        statusElement.classes.add('error');
    } else {
        statusElement.classes.remove('error');
    }
  }
  
  _handleConnectClick(MouseEvent e){
    (e.target as ButtonElement).disabled = true;
    if (socketId != null) {
        _disconnect();
    } else {
        _connect();
    }
  }
  
  _connect(){
    setStatus("");
    var connectionAddr = querySelector('#connectionAddr');
    String addr = connectionAddr.value;
    //should be address with port like xx.xx.xx.xx:xxxx
    //Validation is not included here because error will be thrown by sockets API
    //if address has wrong format.
    var pos = addr.indexOf(':');
    if (pos == -1) {
        setStatus('You must provide port number.', true);
        _connectingError();
        throw "You must provide port number.";
    }
    var ip = addr.substring(0, pos);
    var port = int.parse(addr.substring(pos + 1));
    
    print('Connecting to remote machine at IP: $ip on port: $port');
    setStatus('Connecting...');
    
    chrome.sockets.tcp.create().then((chrome.CreateInfo createInfo){
      print('createInfo: socketId: ${createInfo.socketId}');
      socketId = createInfo.socketId;
      chrome.sockets.tcp.connect(socketId, ip, port).then((int result){
        print('Connection code: $result');
        if (result < 0) {
            setStatus('Unable connect to remote address', true);
            chrome.sockets.tcp.close(socketId);
            socketId = null;
            _disconnected();
            throw "Unable to connect to the remote machine.";
        }
        _connected();
        chrome.sockets.tcp.setPaused(socketId, false);
      }).catchError((_){
        setStatus('Unable connect to remote address', true);
        chrome.sockets.tcp.close(socketId);
        socketId = null;
        _disconnected();
        throw "Unable to connect to the remote machine.";
      });
    });
  }
  
  _connected(){
    print('Connected!');
    (querySelector('#connectButton') as ButtonElement).disabled = false;
    (querySelector('#connectButton') as ButtonElement).text = 'Disconnect';
    (querySelector('#sendButton') as ButtonElement).disabled = false;
    (querySelector('#message') as TextAreaElement).readOnly = false;
    setStatus('Connected');
  }
  
  _connectingError(){
    (querySelector('#connectButton') as ButtonElement).disabled = false;
  }
  
  Future _disconnect(){
    setStatus('Disconnecting...');
    return chrome.sockets.tcp.disconnect(socketId).then(_dispose);
  }
  
  Future _dispose([_]){
    return chrome.sockets.tcp.close(socketId).then((_){
      setStatus('Not connected');
      _disconnected();
      socketId = null;
    });
  }
  
  _disconnected(){
    (querySelector('#connectButton') as ButtonElement).disabled = false;
    (querySelector('#connectButton') as ButtonElement).text = 'Connect';
    (querySelector('#sendButton') as ButtonElement).disabled = true;
    (querySelector('#message') as TextAreaElement).readOnly = true;
  }
  
  _onReceive(chrome.ReceiveInfo info){
    if (info.socketId != socketId) {
        return; // Some other connection.
    }
    chrome.ArrayBuffer data = info.data; //ArrayBuffer with a maxium size of bufferSize.
    
    var str = UTF8.decode(data.getBytes());
    
    var out = new OutputElement();
    out.text = str;
    querySelector('#output').append(out);
  }
  
  _onReceiveError(chrome.ReceiveErrorInfo info){
    if (info.socketId != socketId) {
        return; // Some other connection.
    }
    var code = info.resultCode;

    if (code == -15) {
        // An error code of -15 indicates the port is closed.
        print('Port is closed. Code: -15');
        _dispose();
    } else {
        print('socket error with code: $code');
        _disconnect().then((_){
          setStatus('Socket error with code: ' + code, true);
        });
    }
  }
  
  _handleSendClick(MouseEvent e){
    setStatus('');
    var message = (querySelector('#message') as TextAreaElement).value;
    var data = str2ab(message);
    chrome.sockets.tcp.send(socketId, data).then((chrome.SendInfo sendInfo){
      if(sendInfo.resultCode < 0){
          setStatus('Message not sent.', true);
      } else {
          setStatus('Message sent.');
      }
    });
  }
  
  chrome.ArrayBuffer str2ab(String message){
    List<int> buffer = UTF8.encode(message);
    chrome.ArrayBuffer buf = new chrome.ArrayBuffer.fromBytes(buffer);
    
    return buf;
  }
}