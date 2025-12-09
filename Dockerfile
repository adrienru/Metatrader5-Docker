# ==========================================
# ETAPA 1: BUILDER DE TERMINAL (st)
# ==========================================
FROM alpine:3.18 AS st-builder

RUN apk update && apk add --no-cache \
    make gcc git musl-dev \
    freetype-dev fontconfig-dev \
    libx11-dev libxext-dev libxft-dev \
    ncurses-dev

RUN git clone https://github.com/DenisKramer/st.git /work
WORKDIR /work
RUN make

# ==========================================
# ETAPA 2: BUILDER DUMMY (Video)
# ==========================================
FROM alpine:3.18 AS xdummy-builder
RUN mkdir -p /usr/bin && touch /usr/bin/Xdummy.so

# ==========================================
# ETAPA 3: IMAGEN FINAL (RUNTIME)
# ==========================================
FROM alpine:3.18

USER root
# Variables de entorno CRÍTICAS para Wine
ENV WINEPREFIX=/root/.wine
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV DISPLAY=:0
ENV USER=root
ENV PASSWORD=root

# Repositorios extra
RUN echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories \
    && echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/main" >> /etc/apk/repositories

# 1. INSTALACIÓN DE PAQUETES (Incluye wine, python, etc.)
RUN apk update && apk add --no-cache \
    supervisor sudo wget \
    python3 py3-pip libzmq \
    xorg-server xf86-video-dummy \
    x11vnc \
    openbox \
    slim consolekit \
    font-noto \
    freetype fontconfig xset \
    ncurses \
    samba-winbind wine

# 2. INSTALAR PYZMQ (Python)
RUN pip3 install --no-cache-dir pyzmq

# 3. CONFIGURAR USUARIO (Sin tocar wine links)
RUN echo "$USER:$PASSWORD" | /usr/sbin/chpasswd

# --------------------------------------------------------
# 4. LA SOLUCIÓN RECOMENDADA (Configuración de Wine vía Registro)
# --------------------------------------------------------
# Inicializamos Wine (crea las carpetas .wine)
RUN wineboot --init && \
    sleep 5 && \
    while pgrep wineserver >/dev/null 2>&1; do sleep 1; done

# Editamos el registro para FORZAR Windows 10 (Sin usar winecfg gráfico)
RUN wine reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d win10 /f && \
    wine reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion" /v CurrentVersion /t REG_SZ /d 10.0 /f && \
    wine reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion" /v CurrentBuildNumber /t REG_SZ /d 19044 /f

# 5. DESCARGAR INSTALADOR MT5
RUN mkdir -p /root/Metatrader && \
    wget -O /root/Metatrader/mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

# --------------------------------------------------------
# RESTO DE CONFIGURACIONES (Copia de archivos)
# --------------------------------------------------------
# Copiar terminal compilada
COPY --from=st-builder /work/st /usr/bin/st
COPY --from=st-builder /work/st.info /etc/st/st.info
RUN tic -sx /etc/st/st.info

# Copiar Assets (Configuraciones)
COPY assets/xorg.conf /etc/X11/xorg.conf
COPY assets/xorg.conf.d /etc/X11/xorg.conf.d
COPY assets/supervisord.conf /etc/supervisord.conf
COPY assets/openbox/rc.xml /etc/xdg/openbox/rc.xml
COPY assets/openbox/menu.xml /etc/xdg/openbox/menu.xml
COPY assets/x11vnc-session.sh /root/x11vnc-session.sh
COPY assets/start.sh /root/start.sh

WORKDIR /root/
EXPOSE 5900 15555 15556 15557 15558
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
