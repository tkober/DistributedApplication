//
//  AVASocketServer.h
//  AVA
//
//  Created by Thorsten Kober on 24.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

#ifndef AVASocketServer_h
#define AVASocketServer_h

#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>


extern int POSIXSocketBufferSize;


typedef void(^POSIXServerSocketAcceptCallback)(char *address, in_port_t port);
typedef void(^POSIXServerSocketReadCallback)(char *data, ssize_t length);

int setup_posix_server_socket(in_port_t port);
void start_posix_server_socket(int socket_fd, int backlog, POSIXServerSocketAcceptCallback acceptCallback, POSIXServerSocketReadCallback readCallback);


#endif /* AVASocketServer_h */
