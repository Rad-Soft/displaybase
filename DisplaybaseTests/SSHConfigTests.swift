//
//  SSHConfigTests.swift
//  DisplaybaseTests
//
//  Created by Geeth Gunnampalli on 11/23/26.
//

import Testing

struct SSHConfigTests {
    @Test("the real hostname and port come from ssh -G, not the alias")
    func hostAndPort() {
        let config = "user me\nhostname 192.0.2.10\nport 2200\nidentityfile ~/.ssh/id_ed25519\n"
        #expect(RemoteComputer.target(from: config, host: "gaming") == .init(hostname: "192.0.2.10", port: "2200", proxied: false))
    }

    @Test("without them it falls back to the alias and the standard port")
    func defaults() {
        #expect(RemoteComputer.target(from: "", host: "gaming") == .init(hostname: "gaming", port: "22", proxied: false))
        #expect(RemoteComputer.target(from: "user me\nbatchmode no", host: "gaming").hostname == "gaming")
    }

    @Test("a jump host or proxy command means the port can't be tried directly")
    func proxied() {
        #expect(RemoteComputer.target(from: "hostname pc\nproxyjump bastion\n", host: "pc").proxied)
        #expect(RemoteComputer.target(from: "hostname pc\nproxycommand ssh -W %h:%p bastion\n", host: "pc").proxied)
    }

    @Test("proxies set to none are no proxy")
    func noProxy() {
        #expect(!RemoteComputer.target(from: "proxyjump none\n", host: "pc").proxied)
        #expect(!RemoteComputer.target(from: "proxycommand none\n", host: "pc").proxied)
    }

    @Test("a real proxy isn't undone by another setting saying none")
    func proxyThenNone() {
        #expect(RemoteComputer.target(from: "proxyjump bastion\nproxycommand none\n", host: "pc").proxied)
        #expect(RemoteComputer.target(from: "proxycommand none\nproxyjump bastion\n", host: "pc").proxied)
    }

    @Test("lines without a value are skipped")
    func bareLines() {
        let config = "hostname\nport\nproxyjump\nhostname real\n"
        #expect(RemoteComputer.target(from: config, host: "pc") == .init(hostname: "real", port: "22", proxied: false))
    }
}
