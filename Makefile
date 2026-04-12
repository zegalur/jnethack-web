# Variants:
# 	1. `make clean` - delete the current build
# 	2. `make` - build the whole project
# 	3. `make link` - re-link only
# 	4. `make upd` - only update the htmls etc.

# Default build mode (use `make BUILD=debug` or `make BUILD=release`)
BUILD := release


################################# Directories #################################

JNETHACK_DIR := jnethack-release
SRC_DIR := $(JNETHACK_DIR)/src
JAPANESE_DIR := $(JNETHACK_DIR)/japanese
SYS_UNIX_DIR := $(JNETHACK_DIR)/sys/unix
SYS_SHARE_DIR := $(JNETHACK_DIR)/sys/share
UTILS_DIR := $(JNETHACK_DIR)/util
WIN_TTY_DIR := $(JNETHACK_DIR)/win/tty
WIN_CURSES_DIR := $(JNETHACK_DIR)/win/curses
INCLUDE_DIR := $(JNETHACK_DIR)/include
BUILD_DIR := build
RELEASE_DIR := release
DATA_DIR := data
JNETHACK_FILES_DIR := jnethack-files
JNETHACK_OPTIONS_DIR := jnethack-options
XTERM_PTY_DIR := xterm-pty


############################### Compiler Setup ################################

EMCC := emcc

ifeq ($(BUILD), debug)
	C_OPT := -g3 -O0 -fno-inline
	L_OPT := -g3 -O0 -sASSERTIONS=2 -sSAFE_HEAP=1 -sSTACK_OVERFLOW_CHECK=2 -gsource-map --source-map-base=http://localhost:8000/ --emit-symbol-map -sMINIFY_HTML=0
else
	C_OPT := -O2
	L_OPT := -O2
endif

CFLAGS := \
	-I$(INCLUDE_DIR) \
	-Iother \
	$(C_OPT)

LDFLAGS := \
	-s FORCE_FILESYSTEM -s ASYNCIFY -s ASYNCIFY_STACK_SIZE=5120000 \
	-lidbfs.js \
	--js-library=$(XTERM_PTY_DIR)/emscripten-pty.js \
	-sEXPORTED_FUNCTIONS=_main,_xterm_js_on_resize \
	-sEXPORTED_RUNTIME_METHODS=FS,IDBFS,ccall,callMain \
	-sENVIRONMENT=web \
	-Wl,--wrap=getmailstatus,--wrap=nh_compress,--wrap=nh_uncompress \
	$(L_OPT)


############################# Game Defines ####################################

# Setup game directory
HACKDIR := .
CFLAGS += -DHACKDIR=\"$(HACKDIR)\"
CFLAGS += -DSYSCF -DSYSCF_FILE=\"$(HACKDIR)/sysconf\" -DSECURE

# Other defines
CFLAGS += -DDLB
CFLAGS += -DCOMPRESS=\"/bin/gzip\" -DCOMPRESS_EXTENSION=\".gz\"
CFLAGS += -DTIMED_DELAY
CFLAGS += -DDUMPLOG
CFLAGS += -DCONFIG_ERROR_SECURE=FALSE
CFLAGS += -DTTY_GRAPHICS
#CFLAGS += -DCURSES_GRAPHICS


########################## Find all source files ##############################

SRC_FILES := \
	allmain.c   alloc.c     apply.c     artifact.c  attrib.c    ball.c     \
	bones.c     botl.c      cmd.c       dbridge.c   decl.c      detect.c   \
	dig.c       display.c   dlb.c       do.c        do_name.c   do_wear.c  \
	dog.c       dogmove.c   dokick.c    dothrow.c   drawing.c   dungeon.c  \
	eat.c       end.c       engrave.c   exper.c     explode.c   extralev.c \
	files.c     fountain.c  hack.c      hacklib.c   invent.c    isaac64.c  \
	light.c     lock.c      mail.c      makemon.c   mapglyph.c  mcastu.c   \
	mhitm.c     mhitu.c     minion.c    mklev.c     mkmap.c     mkmaze.c   \
	mkobj.c     mkroom.c    mon.c       mondata.c   monmove.c   monstj.c   \
	mplayer.c   mthrowu.c   muse.c      music.c     o_init.c    objectsj.c \
	objnam.c    options.c   pager.c     pickup.c    pline.c     polyself.c \
	potion.c    pray.c      priest.c    quest.c     questpgr.c  read.c     \
	rect.c      region.c    restore.c   rip.c       rnd.c       role.c     \
	rumors.c    save.c      shk.c       shknam.c    sit.c       sounds.c   \
	sp_lev.c    spell.c     steal.c     steed.c     sys.c       teleport.c \
	timeout.c   topten.c    track.c     trap.c      u_init.c    uhitm.c    \
	vault.c     version.c   vision.c    weapon.c    were.c      wield.c    \
	windows.c   wizard.c    worm.c      worn.c      write.c     zap.c      \
	vis_tab.c
	
SYS_SHARE_FILES := \
	ioctl.c unixtty.c \
	posixregex.c
#	dgn_lex.c dgn_yacc.c lev_lex.c lev_yacc.c \

SYS_UNIX_FILES := \
	unixmain.c unixres.c unixunix.c

WIN_TTY_FILES:= \
	getline.c termcap.c topl.c wintty.c

# Curses disabled
WIN_CURSES_FILES := 
#	cursdial.c cursinit.c \
#	cursinvt.c cursmain.c cursmesg.c \
#	cursmisc.c cursstat.c curswins.c

JAPANESE_FILES := \
	jconj.c jlib.c

SRC := \
    $(addprefix $(SRC_DIR)/, $(SRC_FILES)) \
    $(addprefix $(SYS_SHARE_DIR)/, $(SYS_SHARE_FILES)) \
    $(addprefix $(SYS_UNIX_DIR)/, $(SYS_UNIX_FILES)) \
    $(addprefix $(WIN_TTY_DIR)/, $(WIN_TTY_FILES)) \
    $(addprefix $(WIN_CURSES_DIR)/, $(WIN_CURSES_FILES)) \
    $(addprefix $(JAPANESE_DIR)/, $(JAPANESE_FILES))


###############################################################################

# Convert $(JNETHACK_DIR)/...c → $(BUILD_DIR)/...o
OBJ := $(patsubst $(JNETHACK_DIR)/%.c,$(BUILD_DIR)/%.o,$(SRC))

# Dependency files
DEP := $(OBJ:.o=.d)

# Output executable
TARGET := $(RELEASE_DIR)/jnethack.mjs

# Default target
all: $(TARGET)

# Link
$(TARGET): $(OBJ) $(BUILD_DIR)/wrappers.o
	@echo "LDFLAGS=$(LDFLAGS)"
	@mkdir -p $(RELEASE_DIR)
	$(EMCC) \
		--preload-file $(JNETHACK_FILES_DIR)@/ \
		--preload-file $(JNETHACK_OPTIONS_DIR)/.jnethackrc@/home/web_user/.jnethackrc \
		$(LDFLAGS) -o $@ \
		$(OBJ) \
		$(BUILD_DIR)/wrappers.o
	cp -r $(DATA_DIR)/. $(RELEASE_DIR)

# Compile
$(BUILD_DIR)/%.o: $(JNETHACK_DIR)/%.c
	@mkdir -p $(dir $@)
	$(EMCC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/wrappers.o: other/wrappers.c
	@mkdir -p $(dir $@)
	$(EMCC) $(CFLAGS) -c $< -o $@

# Include dependency files
-include $(DEP)

# Clean
clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(RELEASE_DIR)

# Use this to re-link the project:
link:
	rm -rf $(RELEASE_DIR)/*
	$(MAKE) all

# Use this to update the data:
upd:
	cp -r $(DATA_DIR)/. $(RELEASE_DIR)

.PHONY: all clean
