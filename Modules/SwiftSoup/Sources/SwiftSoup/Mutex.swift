//
//  Mutex.swift
//  SwiftSoup
//
//  Created by xukun on 2022/3/31.
//

import Foundation

#if os(Windows)
import WinSDK
#endif

final class Mutex: NSLocking {
#if os(Windows)
    private var mutex = CRITICAL_SECTION()

    init() {
        InitializeCriticalSection(&mutex)
    }

    deinit {
        DeleteCriticalSection(&mutex)
    }

    func lock() {
        EnterCriticalSection(&mutex)
    }

    func unlock() {
        LeaveCriticalSection(&mutex)
    }
#else
    private var mutex = pthread_mutex_t()

    init() {
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    func lock() {
        pthread_mutex_lock(&mutex)
    }

    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
#endif
}
