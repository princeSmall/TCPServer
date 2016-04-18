//
//  main.m
//  TCPServer
//
//  Created by tongle on 16/4/15.
//  Copyright © 2016年 tongle. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#define PORT 9000
void AcceptCallBack(CFSocketRef,CFSocketCallBackType,CFDataRef,const void *,void *);
void WriteStreamClientCallBack(CFWriteStreamRef stream,CFStreamEventType eventType,void *);
void ReadStreamClientCallBack (CFReadStreamRef stream,CFStreamEventType eventType,void *);
/* 服务器接受到客户端请求后回调 */
typedef void (* CFSocketCallBack)(
       CFSocketRef s,
       CFSocketCallBackType callbacktype,
       CFDataRef address,
       const void * data,
       void * info
);
/* 当客户端在socket中读取数据时调用 */
typedef void (* CFWriteStreamClientCallBack)(
       CFWriteStreamRef stream,
       CFStreamEventType evenType,
       void * clientCallBackInfo
);
/* 当客户端在把数据写入socket时调用 */
typedef void (* CFReadStreamClientCallBack)(
       CFReadStreamRef stream,
       CFStreamEventType evenType,
       void * clientCallBackInfo
);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
       /*定义一个 server socket 引用*/
        CFSocketRef sserver;
        /*创建 socket context */
        CFSocketContext CTX ={0,NULL,NULL,NULL,NULL};
        /*创建server socket TCP IPv4 设置回调函数 */
        sserver = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)AcceptCallBack,&CTX);
        if (sserver == NULL)
            return -1;
        
        /* 设置是否重新绑定 */
        int yes = 1;
        /* 设置socket属性 SOL——socket是设置tcp so_reuseaddr重新绑定 */
        setsockopt(CFSocketGetNative(sserver), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
        
        /* 设置端口和地址 */
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));   //memset 函数对指定的地址进行内存复制
        addr.sin_len = sizeof(addr);
        addr.sin_family = AF_INET;        //AF_INET 是设置IPv4
        addr.sin_port = htons(PORT);      //htons函数 无符号短整型数转换成“网络字节序”
        addr.sin_addr.s_addr = htonl(INADDR_ANY); //INADDR_ANY 有内核分配
        
        /* 从指定字节缓冲区复制，一个不可变的CFData对象 */
        CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr, sizeof(addr));
        /* 绑定socket */
        if (CFSocketSetAddress(sserver, (CFDataRef )address)!=kCFSocketSuccess) {
            fprintf(stderr, "socket 绑定失败\n");
            return -1;
        }
        /*  创建一个run loop socket 源 */
        CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, sserver, 0);
        /* socket 源添加到 runloop 中 */
        CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopCommonModes);
        printf(" socket listening on port %d\n",PORT);
        /* 运行runloop */
        CFRunLoopRun();
    }
    return 0;
}
/*  CFSocketContext提供程序定义数据和回调函数 */
struct  CFSocketContext{
    CFIndex version;
    void * info;
    CFAllocatorRetainCallBack retain;
    CFAllocatorReleaseCallBack release;
    CFAllocatorCopyDescriptionCallBack copyDescription;
};
typedef struct CFSocketContext CFcontext;
/* CFSocketCreate 创建socket对象 */
CFSocketRef CFSocketCreate(
                           CFAllocatorRef allcator,
                           SInt32 protocalFamily,
                           SInt32 socketType,
                           SInt32 protocol,
                           CFOptionFlags callBackTypes,
                           CFSocketCallBack callout,
                           const CFSocketContext * content
);


/* 接受客户端请求后，回调函数 */
void AcceptCallBack(
                    CFSocketRef socket,
                    CFSocketCallBackType type,
                    CFDataRef address,
                    const void * data,
                    void * info
){
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    CFSocketNativeHandle sock = * (CFSocketNativeHandle *)data;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
    if (!readStream ||!writeStream) {
        close(sock);
        fprintf(stderr, "CFStreamCreatePairWithSocket () 失败\n");
        return;
    }
    CFStreamClientContext streamCtxt = {0,NULL,NULL,NULL,NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable, ReadStreamClientCallBack, &streamCtxt);
    CFWriteStreamSetClient(writeStream, kCFStreamEventCanAcceptBytes, WriteStreamClientCallBack, &streamCtxt);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFWriteStreamScheduleWithRunLoop(writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamOpen(readStream);
    CFWriteStreamOpen(writeStream);
}
/* 链接socket并创建输入输出流对象 */
void CFStreamCreatePairWithSocket(
                                  CFAllocatorRef alloc,
                                  CFSocketNativeHandle sock,
                                  CFReadStreamRef * readStream,
                                  CFWriteStreamRef * writeStream
);
/* 读取流操作，客户端有数据过来时调用 */
void ReadStreamClientCallBack(CFReadStreamRef stream,CFStreamEventType evenType,void * clientCallBackInfo){
    UInt8 buff[255];
    CFReadStreamRef inputStream =stream;
    if (NULL!= inputStream) {
        CFReadStreamRead(stream, buff, 255);
        printf("接收到数据:%s\n",buff);
        CFReadStreamClose(inputStream);
        CFReadStreamUnscheduleFromRunLoop(inputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        inputStream = NULL;
    }
};
/* 写入流操作，客户端在读取数据时调用 */
void WriteStreamClientCallBack(CFWriteStreamRef stream,CFStreamEventType eventType,void * clientCallBackInfo){
    CFWriteStreamRef outputStream = stream;
    UInt8 buff[] = "Hello Client";
    if (NULL != outputStream) {
        CFWriteStreamWrite(outputStream, buff, strlen((const char *)buff)+1);
        CFWriteStreamClose(outputStream);
        CFWriteStreamUnscheduleFromRunLoop(outputStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        outputStream = NULL;
    }
};

/* ReadStreamClientCallBack 函数的第一行接受客户端数据，使用CFReadStreamRead函数，定义如下 */
CFIndex CFReadStreamRead(
                         CFReadStreamRef stream,  //输入流对象
                         UInt8 *buffer,           //接收数据准备的缓冲区
                         CFIndex bufferLength     //读入数据长度
);
/* WriteStreamClientCallBack 函数的第一行接受客户端数据，使用CFWriteStreamWrite函数，定义如下 */
CFIndex CFWriteStreamWrite(
                         CFWriteStreamRef stream,
                         const  UInt8 *buffer,
                         CFIndex bufferLength
 );












