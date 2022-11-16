#!/usr/bin/env bash

# - - - - - - - - - - - - - - General configuration - - - - - - - - - - - - - -

if [[ $( ls /home/vagrant/scripts/ | wc -l ) -ne 0 ]] ; then
  mv /home/vagrant/scripts/* /usr/local/bin
  rm -r /home/vagrant/scripts

  chown root. /usr/local/bin/*
  chmod +x /usr/local/bin/*
fi

apt update
#apt upgrade -y
apt install -y vim

cat << EOF > /etc/vim/vimrc.local
set nomodeline
set bg=dark
set tabstop=2
set expandtab
set ruler
set nu
syntax on
EOF


# - - - - - - - - - - - - - - Graylog server - - - - - - - - - - - - - -

if [[ "$1" == "graylog" ]] ; then
echo "nslcd nslcd/ldap-base string dc=intnet" | debconf-set-selections && \
echo "nslcd nslcd/ldap-uris string ldap://192.168.68.11" | debconf-set-selections && \
echo "libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group, shadow" | debconf-set-selections && \
echo "libnss-ldapd:amd64 libnss-ldapd/nsswitch multiselect passwd, group, shadow" | debconf-set-selections && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y nslcd

cat << 'EOF' > /usr/share/pam-configs/mkhomedir
Name: Create home directory during login
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required        pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF
pam-auth-update --enable mkhomedir
systemctl restart nslcd.service nscd.service
fi


# - - - - - - - - - - - - - - Generic Linux server - - - - - - - - - - - - - -

if [[ "$1" == "linserver" ]] ; then
echo "slapd slapd/root_password password rnpesr"       | debconf-set-selections && \
echo "slapd slapd/root_password_again password rnpesr" | debconf-set-selections && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils ldapscripts

echo "slapd slapd/no_configuration boolean false" | debconf-set-selections
echo "slapd slapd/domain string intnet"           | debconf-set-selections
echo "slapd shared/organization string corev"     | debconf-set-selections
echo "slapd slapd/password1 password rnpesr"      | debconf-set-selections
echo "slapd slapd/password2 password rnpesr"      | debconf-set-selections
echo "slapd slapd/backend select MDB"             | debconf-set-selections
echo "slapd slapd/purge_database boolean true"    | debconf-set-selections
echo "slapd slapd/allow_ldap_v2 boolean false"    | debconf-set-selections
echo "slapd slapd/move_old_database boolean true" | debconf-set-selections
  dpkg-reconfigure -f noninteractive slapd

echo "nslcd nslcd/ldap-base string dc=intnet" | debconf-set-selections && \
echo "nslcd nslcd/ldap-uris string ldapi:///" | debconf-set-selections && \
echo "libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group, shadow" | debconf-set-selections && \
echo "libnss-ldapd:amd64 libnss-ldapd/nsswitch multiselect passwd, group, shadow" | debconf-set-selections && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y nslcd

sed -i 's/^#\(BASE\).*/\1 dc=intnet/' /etc/ldap/ldap.conf; \
sed -i 's/^#\(URI\).*/\1 ldapi\:\/\/\//' /etc/ldap/ldap.conf

sed -i 's/^\(BINDDN=\).*/\1\"cn=admin,dc=intnet\"/' /etc/ldapscripts/ldapscripts.conf
echo -n "rnpesr" > /etc/ldapscripts/ldapscripts.passwd
ldapinit -s

ldapmodify -Y external -H ldapi:/// << 'EOF'
dn: cn=config
changeType: modify
replace: olcLogLevel
olcLogLevel: stats
EOF

ldapmodify -Y external -H ldapi:/// << 'EOF'
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcDbIndex
olcDbIndex: objectClass eq
olcDbIndex: cn pres,sub,eq
olcDbIndex: sn pres,sub,eq
olcDbIndex: uid pres,sub,eq
olcDbIndex: displayName pres,sub,eq
olcDbIndex: default sub
olcDbIndex: uidNumber eq
olcDbIndex: gidNumber eq
olcDbIndex: mail,givenName eq,subinitial
olcDbIndex: dc eq
EOF

ldapmodify -Y external -H ldapi:/// << 'EOF'
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {1}to attrs=loginShell,gecos
  by dn="cn=admin,dc=intnet" write
  by self write
  by * read
EOF

cat << 'EOF' > /etc/rsyslog.d/slapd.conf
$template slapdtmpl,"[%$DAY%-%$MONTH%-%$YEAR% %timegenerated:12:19:date-rfc3339%] %app-name% %syslogseverity-text% %msg%\n"
local4.*    /var/log/slapd.log;slapdtmpl
EOF

cat << 'EOF' > /etc/logrotate.d/slapd
/var/log/slapd.log {
  missingok
  notifempty
  compress
  daily
  rotate 30
  sharedscripts
  postrotate
    systemctl restart rsyslog.service
  endscript
}
EOF

systemctl restart rsyslog.service slapd.service

ldapaddgroup sysadm
ldapadduser charlie sysadm
ldapaddusertogroup charlie sysadm
ldappasswd -x -D "cn=admin,dc=intnet" -w "rnpesr" "uid=charlie,ou=People,dc=intnet" -s "password"

cat << 'EOF' > /usr/share/pam-configs/mkhomedir
Name: Create home directory during login
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required        pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF
pam-auth-update --enable mkhomedir
systemctl restart nslcd.service nscd.service
fi


# - - - - - - - - - - - - - - - - - Reboot - - - - - - - - - - - - - - - - -

reboot

