/*
	
	TCP Server test for M4 Board
	Duke 2016

*/
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#include <errno.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>

#ifdef __WIN32__
#include <windows.h>
#include <winsock2.h>
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/uio.h>
#include <sys/ioctl.h>
#include <sys/fcntl.h>
#include <netinet/tcp.h>
#endif


int main(int argc, char *argv[])
{
	int listensock, cmdsock, addrlen, optval, n;
	volatile int leave = 0;
	struct sockaddr_in serv_addr;
	struct sockaddr_in pin;
	char recvbuf[2048];
	
#ifdef __WIN32__
	WSADATA WsaDat;
	WSAStartup(MAKEWORD(2,2),&WsaDat);		
#endif	
	addrlen = sizeof(pin); 
	memset(&serv_addr, 0, sizeof(serv_addr));
	
	listensock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
	optval = 1;
  	setsockopt(listensock, SOL_SOCKET, SO_REUSEADDR, (const void *)&optval , sizeof(int));
	     
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = INADDR_ANY;
	serv_addr.sin_port = htons(0x1234); 
	
	
	if ( bind(listensock, (struct sockaddr*)&serv_addr, sizeof(serv_addr)  )< 0 )
	{	printf("bind failed\n");
		closesocket(listensock);
		return;
	}

	listen(listensock, 1); 
	printf("Listening to port 0x1234\n");

	while ( 1 )
	{	
		printf("Waiting for connection!\n");
		
		cmdsock = accept(listensock, (struct sockaddr *)  &pin, &addrlen);
		
		if ( cmdsock >= 0 )
		{	printf("Client connected\n");
			
			while( 1 )
			{
				n = recv(cmdsock, recvbuf, 200, 0);
				if ( n <= 0 )
				{	printf("Client disconnected!\n");
					break;	
				}
				recvbuf[n] = 0;
				printf(">%s\r\n", recvbuf);
				// echo it back
				send(cmdsock, recvbuf, n, 0);
			}
		}
	
	}
	closesocket(cmdsock);
	closesocket(listensock);
	
#ifdef __WIN32__	
	WSACleanup();
#endif
	
}