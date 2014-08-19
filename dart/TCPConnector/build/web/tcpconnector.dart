library tcpconnector;

import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:chrome/chrome_app.dart' as chrome;

///App's entry point
void main() {
  new Tcp();
}

/**
 * [Tcp] class is an example of TCP connection via chrome.sockets API.
 * It's JavaScript's version is available on GitHub: 
 * https://github.com/jarrodek/gdg/tree/master/chrome/TCPConnector
 * 
 * @author Paweł Psztyć, GDG Warszawa 
 */
class Tcp {
  /// Socket that the app is operation on
  int socketId;

  /// Handle controls listeners.
  Tcp() {
    querySelector('#connectButton').onClick.listen(_handleConnectClick);
    querySelector('#sendButton').onClick.listen(_handleSendClick);
    chrome.sockets.tcp.onReceive.listen(_onReceive);
    chrome.sockets.tcp.onReceiveError.listen(_onReceiveError);
  }

  /**
   * Set [status] in message field. If [error] is set to true
   * it will add "error" class. 
   */
  setStatus(String status, [bool error]) {
    var statusElement = querySelector('#status');
    statusElement.text = status;
    if (error) {
      statusElement.classes.add('error');
    } else {
      statusElement.classes.remove('error');
    }
  }

  ///Connect or disconnect from the socket.
  _handleConnectClick(MouseEvent e) {
    (e.target as ButtonElement).disabled = true;
    if (socketId != null) {
      _disconnect();
    } else {
      _connect();
    }
  }

  ///Make a connection to given IP andress and port.
  _connect() {
    setStatus("");
    var connectionAddr = querySelector('#connectionAddr');
    String addr = connectionAddr.value;
    //should be the address with port like xx.xx.xx.xx:xxxx
    //Validation is not included here because error will be thrown by sockets API
    //if address has wrong format.
    var pos = addr.indexOf(':');
    if (pos == -1) {
      setStatus('You must provide port number.', true);
      _connectingError();
      //break here
      throw "You must provide port number.";
    }
    var ip = addr.substring(0, pos);
    var port = int.parse(addr.substring(pos + 1));

    print('Connecting to remote machine at IP: $ip on port: $port');
    setStatus('Connecting...');

    // First the app need to create the socket.
    chrome.sockets.tcp.create().then((chrome.CreateInfo createInfo) {
      print('createInfo: socketId: ${createInfo.socketId}');
      socketId = createInfo.socketId;
      // Then, the app can connect to the peer.
      chrome.sockets.tcp.connect(socketId, ip, port).then((int result) {
        print('Connection code: $result');
        if (result < 0) {
          // if result is less than 0 means error. 
          setStatus('Unable connect to remote address', true);
          // Don't forget to clean up
          chrome.sockets.tcp.close(socketId);
          socketId = null;
          _disconnected();
          throw "Unable to connect to the remote machine.";
        }
        _connected();
      }).catchError((_) {
        //Can't connect. No internet connection or wrong address.
        setStatus('Unable connect to remote address', true);
        chrome.sockets.tcp.close(socketId);
        socketId = null;
        _disconnected();
        throw "Unable to connect to the remote machine.";
      });
    });
  }
  
  /// Set UI controls to "connected" state
  _connected() {
    print('Connected!');
    (querySelector('#connectButton') as ButtonElement).disabled = false;
    (querySelector('#connectButton') as ButtonElement).text = 'Disconnect';
    (querySelector('#sendButton') as ButtonElement).disabled = false;
    setStatus('Connected');
  }

  _connectingError() {
    (querySelector('#connectButton') as ButtonElement).disabled = false;
  }
  
  /// Disconnect is a two steps operation: disconnect from peer and close socket. 
  Future _disconnect() {
    setStatus('Disconnecting...');
    return chrome.sockets.tcp.disconnect(socketId).then(_dispose);
  }
  /// Release socket resources 
  Future _dispose([_]) {
    return chrome.sockets.tcp.close(socketId).then((_) {
      setStatus('Not connected');
      _disconnected();
      socketId = null;
    });
  }

  _disconnected() {
    (querySelector('#connectButton') as ButtonElement).disabled = false;
    (querySelector('#connectButton') as ButtonElement).text = 'Connect';
    (querySelector('#sendButton') as ButtonElement).disabled = true;
  }
  
  /// This is callback function when socket receive a data from peer.
  _onReceive(chrome.ReceiveInfo info) {
    if (info.socketId != socketId) {
      return; // Some other connection.
    }
    chrome.ArrayBuffer data = info.data; //ArrayBuffer with a maxium size of bufferSize.
    
    //To decode message to string we can use [UTF] class and decode method.
    var str; 
    try{
      str = UTF8.decode(data.getBytes(), allowMalformed: true);
    } catch(e){
      str = 'decoding error';
    }

    var out = new OutputElement();
    out.text = str;
    querySelector('#output').append(out);
  }
  
  ///This method is called when socket receive an error. 
  _onReceiveError(chrome.ReceiveErrorInfo info) {
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
      _disconnect().then((_) {
        setStatus('Socket error with code: ' + code, true);
      });
    }
  }
  
  ///Callback function for user's click to the send button.
  _handleSendClick(MouseEvent e) {
    setStatus('');
    var message = (querySelector('#message') as TextAreaElement).value;
    _sendMessage(message);
  }
  
  ///Send the message via opened socket.
  _sendMessage(String message){
    //message must to be converted to JavaScript's ArrayBuffer.
    var data = str2ab(message);
    chrome.sockets.tcp.send(socketId, data).then((chrome.SendInfo sendInfo) {
      if (sendInfo.resultCode < 0) {
        setStatus('Message not sent.', true);
      } else {
        setStatus('Message sent.');
      }
    });
  }
  
  ///Convert string message to JavaScript's ArrayBuffer.
  chrome.ArrayBuffer str2ab(String message) {
    List<int> buffer = UTF8.encode(message);
    chrome.ArrayBuffer buf = new chrome.ArrayBuffer.fromBytes(buffer);

    return buf;
  }
}
