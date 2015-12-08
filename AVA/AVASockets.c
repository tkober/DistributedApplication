//
//  AVASocketServer.c
//  AVA
//
//  Created by Thorsten Kober on 24.11.15.
//  Copyright © 2015 Thorsten Kober. All rights reserved.
//

#include "AVASockets.h"


int POSIXSocketBufferSize = 1024;


extern void start_reading_posix_socket(int socket_fd, POSIXServerSocketReadCallback readCallback);


int setup_posix_server_socket(in_port_t port)
{
    int socket_fd;
    struct sockaddr_in server_address;
    
    socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    assert(socket_fd > 0);
    
    bzero((char *)&server_address, sizeof(server_address));
    
    server_address.sin_family = AF_INET;
    server_address.sin_addr.s_addr = INADDR_ANY;
    server_address.sin_port = htons(port);
    
    int status = bind(socket_fd, (struct sockaddr *)&server_address, sizeof(server_address));
    assert(status == 0);
    
    return socket_fd;
}


void start_posix_server_socket(int socket_fd, int backlog, POSIXServerSocketAcceptCallback acceptCallback, POSIXServerSocketReadCallback readCallback)
{
    listen(socket_fd, backlog);
    dispatch_async(dispatch_queue_create("ava.server_socket.acceptance_queue", DISPATCH_QUEUE_SERIAL), ^{
        while (1) {
            socklen_t client_length;
            int new_socket_fd;
            struct sockaddr_in client_address;
            
            client_length = sizeof(client_address);
            
            new_socket_fd = accept(socket_fd, (struct sockaddr *)&client_address, &client_length);
            
            char *address = inet_ntoa(client_address.sin_addr);
            dispatch_async(dispatch_get_main_queue(), ^{
                acceptCallback(address, client_address.sin_port);
            });
            
            dispatch_async(dispatch_queue_create("SOCKET_QUEUE", DISPATCH_QUEUE_SERIAL), ^{
                start_reading_posix_socket(new_socket_fd, readCallback);
            });
        }
    });
}


void start_reading_posix_socket(int socket_fd, POSIXServerSocketReadCallback readCallback)
{
    char buffer[POSIXSocketBufferSize];
    while (1) {
        ssize_t n;
        bzero(buffer, POSIXSocketBufferSize);
        n = read(socket_fd, buffer, POSIXSocketBufferSize-1);
        if (n > 0) {
            char *data = malloc(sizeof(char) * n);
            memcpy(data, buffer, n+1);
            dispatch_async(dispatch_get_main_queue(), ^{
                readCallback(data, n);
            });
            
        }
    }
}




