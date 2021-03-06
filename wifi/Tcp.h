/*
 * Tcp.h
 *
 *  Created on: Oct 24, 2015
 *      Author: lieven
 */

#ifndef TCP_H_
#define TCP_H_
#include "Handler.h"
#include "Stream.h"
#include "CircBuf.h"
#include "Sys.h"
#include "Wifi.h"
extern "C" {
#include "espmissingincludes.h"
#include "user_interface.h"
#include "osapi.h"
#include "espconn.h"
#include "os_type.h"
#include "mem.h"
//#include "mqtt_msg.h"
//#include "user_config.h"

}

typedef enum {

	DNS_RESOLVE,
	TCP_DISCONNECTED,
	TCP_RECONNECT_REQ,
	TCP_RECONNECT,
	TCP_CONNECTING,
	TCP_CONNECTING_ERROR,
	TCP_CONNECTED,

} ConnState;

typedef union {
	uint8_t b[4];
	uint32_t addr;
	ip_addr ipAddr;
} IpAddress;

class Tcp: public Handler, public Stream {
public:
	typedef enum {
		SERVER, CLIENT, LIVE
	} TcpType;
protected:
	Wifi* _wifi;

	uint16_t _remote_port;
	uint16_t _local_port;
	struct espconn* _conn;
	char _host[64];
	bool _connected;

private:

	static Tcp* _first;
	Tcp* _next;
	static uint32_t _maxConnections;
//	ConnState _connState;
//	CircBuf _rxd;
	CircBuf _txd;
	Bytes _buffer;
	uint32_t _connections;
	uint32_t _bytesRxd;
	uint32_t _bytesTxd;
	uint32_t _overflowTxd;
	uint32_t _overflowRxd;
	TcpType _type;
	uint64_t _lastRxd;

public:

	IpAddress _remote_ip;
	Tcp(Wifi* wifi); //
	Tcp(Wifi* wifi, struct espconn* conn); //
	~Tcp(); //
	inline void setType(TcpType t) {
		_type = t;
	}
	inline TcpType getType() {
		return _type;
	}

	void logConn(const char* s, void *arg);
	void loadEspconn(struct espconn* conn);

	void disconnect();

	void registerCb(struct espconn* pconn);	//
	static void globalInit(Wifi* wifi, uint32_t maxConnections);
	static Tcp* findTcp(struct espconn* pconn);
	static void listTcp();
	static Tcp* findFreeTcp(struct espconn* pconn);
	static bool match(struct espconn* pconn, Tcp* pTcp); //
	void reg();
	void unreg();
	uint32_t count(); //
	uint32_t used(); //
	static void connectCb(void* arg);	//
	static void reconnectCb(void* arg, int8 err); // mqtt_tcpclient_recon_cb(void *arg, sint8 errType)
	static void disconnectCb(void* arg); //
	static void dnsFoundCb(const char *name, ip_addr_t *ipaddr, void *arg); //
	static void recvCb(void* arg, char *pdata, unsigned short len); //
	static void sendCb(void* arg); //
	static void writeFinishCb(void* arg); //

	void send();	//
	Erc write(Bytes& bytes); //
	Erc write(uint8_t b); //
	Erc write(uint8_t* pb, uint32_t length); //
	bool hasData(); //
	bool hasSpace(); //
	uint8_t read(); //
	virtual bool dispatch(Msg& msg); //
	bool isConnected(); //

};

class TcpServer: public Tcp {
public:
	TcpServer(Wifi* wifi);
	virtual bool dispatch(Msg& msg); //
	Erc config(uint32_t maxConnections, uint16_t port);
	void listen();
};

class TcpClient: public Tcp {
public:
	TcpClient(Wifi* wifi);
	virtual bool dispatch(Msg& msg); //
	void config(const char* host, uint16_t port);
	void connect();
//	void  connect(const char* host, uint16_t port);

};

#endif /* TCP_H_ */
