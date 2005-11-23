--
-- NAME
--     Public-DNS.org Database Layout
--
-- AUTHOR
--     Joshua I. Miller <unrtst@cpan.org>
--
-- COPYRIGHT AND LICENSE
-- 
-- Copyright (c) 2002 by PurifiedData, LLC.
-- 
-- This library is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License version 2 as
-- published by the Free Software Foundation. (see COPYING)
-- 
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
-- General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
-- 02111-1307, USA
-- 

--
-- Table structure for table 'Deleted_Domains'
--

CREATE TABLE Deleted_Domains (
  DDid int(11) NOT NULL auto_increment,
  ownerid int(11) NOT NULL default '0',
  Cid int(10) unsigned NOT NULL default '0',
  zone char(63) NOT NULL default '',
  tld char(8) NOT NULL default '',
  timestamp timestamp(14) NOT NULL,
  PRIMARY KEY  (DDid)
) TYPE=MyISAM;

--
-- Table structure for table 'Pending'
--

CREATE TABLE Pending (
  Pid int(11) NOT NULL auto_increment,
  PKey varchar(32) NOT NULL default '',
  ownerid int(11) NOT NULL default '0',
  zone varchar(63) NOT NULL default '',
  tld varchar(8) NOT NULL default '',
  master varchar(255) default NULL,
  added datetime NOT NULL default '0000-00-00 00:00:00',
  lastcheck datetime default NULL,
  notified datetime default NULL,
  verifynotify datetime default NULL,
  status varchar(31) NOT NULL default 'Pending Check',
  PRIMARY KEY  (Pid)
) TYPE=MyISAM;

--
-- Table structure for table 'RR_A'
--

CREATE TABLE RR_A (
  RRid int(11) NOT NULL default '0',
  A int(3) NOT NULL default '0',
  B int(3) NOT NULL default '0',
  C int(3) NOT NULL default '0',
  D int(3) NOT NULL default '0'
) TYPE=MyISAM;

--
-- Table structure for table 'RR_AAAA'
--

CREATE TABLE RR_AAAA (
  RRid int(11) NOT NULL default '0',
  value char(40) NOT NULL default ''
) TYPE=MyISAM;

--
-- Table structure for table 'RR_CNAME'
--

CREATE TABLE RR_CNAME (
  RRid int(11) NOT NULL default '0',
  value char(255) NOT NULL default ''
) TYPE=MyISAM;

--
-- Table structure for table 'RR_HINFO'
--

CREATE TABLE RR_HINFO (
  RRid int(11) NOT NULL default '0',
  value1 char(255) NOT NULL default '',
  value2 char(255) NOT NULL default ''
) TYPE=MyISAM;

--
-- Table structure for table 'RR_MX'
--

CREATE TABLE RR_MX (
  RRid int(11) NOT NULL default '0',
  pref tinyint(2) NOT NULL default '10',
  value char(255) NOT NULL default ''
) TYPE=MyISAM;

--
-- Table structure for table 'RR_NS'
--

CREATE TABLE RR_NS (
  RRid int(11) NOT NULL default '0',
  value char(255) NOT NULL default ''
) TYPE=MyISAM;

--
-- Table structure for table 'RR_TXT'
--

CREATE TABLE RR_TXT (
  RRid int(11) NOT NULL default '0',
  value char(255) default NULL
) TYPE=MyISAM;

--
-- Table structure for table 'RRs'
--

CREATE TABLE RRs (
  RRid int(11) NOT NULL auto_increment,
  Cid int(11) NOT NULL default '0',
  record varchar(255) NOT NULL default '',
  TTL int(11) NOT NULL default '86400',
  type varchar(8) NOT NULL default '',
  PRIMARY KEY  (RRid)
) TYPE=MyISAM;

--
-- Table structure for table 'banners'
--

CREATE TABLE banners (
  BannerID int(10) unsigned NOT NULL auto_increment,
  Preferance int(11) NOT NULL default '1',
  linkurl char(255) NOT NULL default '',
  bannerurl char(255) NOT NULL default '',
  active tinyint(4) NOT NULL default '1',
  PRIMARY KEY  (BannerID)
) TYPE=MyISAM;

--
-- Table structure for table 'conf'
--

CREATE TABLE conf (
  Cid int(10) unsigned NOT NULL auto_increment,
  ownerid int(10) unsigned NOT NULL default '0',
  zone varchar(63) NOT NULL default '',
  tld varchar(8) NOT NULL default '',
  serial int(11) NOT NULL default '1',
  refresh int(11) NOT NULL default '10800',
  retry int(11) NOT NULL default '3600',
  expire int(11) NOT NULL default '604800',
  TTL int(11) NOT NULL default '86400',
  master varchar(255) default NULL,
  admin_email varchar(255) default NULL,
  modified tinyint(1) NOT NULL default '1',
  added datetime NOT NULL default '2003-07-30 00:00:01',
  status char(1) NOT NULL default '2',
  PRIMARY KEY  (Cid)
) TYPE=MyISAM;

--
-- Table structure for table 'log'
--

CREATE TABLE log (
  Lid int(11) NOT NULL auto_increment,
  login varchar(255) default NULL,
  uid int(10) unsigned NOT NULL default '0',
  ownerid int(10) unsigned default NULL,
  action varchar(16) default NULL,
  zone varchar(63) default NULL,
  tld varchar(8) default NULL,
  remote_ip varchar(16) default NULL,
  oldvalues text,
  newvalues text,
  timestamp timestamp(14) NOT NULL,
  PRIMARY KEY  (Lid)
) TYPE=MyISAM;

--
-- Table structure for table 'logins'
--

CREATE TABLE logins (
  uid int(10) unsigned NOT NULL auto_increment,
  ownerid int(10) unsigned NOT NULL default '0',
  login varchar(255) NOT NULL default '',
  passwd tinyblob NOT NULL,
  signup datetime default NULL,
  loginclass varchar(8) default NULL,
  sendbackups tinyint(4) NOT NULL default '0',
  disabled char(1) default '0',
  PRIMARY KEY  (uid)
) TYPE=MyISAM;

--
-- Table structure for table 'logins_pending'
--

CREATE TABLE logins_pending (
  uid int(10) unsigned NOT NULL auto_increment,
  login varchar(255) NOT NULL default '',
  passwd tinyblob NOT NULL,
  plain_passwd tinytext NOT NULL,
  signup datetime default NULL,
  PKey varchar(32) default NULL,
  PRIMARY KEY  (uid)
) TYPE=MyISAM;

--
-- Table structure for table 'pending_data'
--

CREATE TABLE pending_data (
  Cid int(10) unsigned NOT NULL default '0',
  lastcheck datetime default NULL,
  notified datetime default NULL,
  PRIMARY KEY  (Cid)
) TYPE=MyISAM;

--
-- Table structure for table 'sessions'
--

CREATE TABLE sessions (
  login varchar(64) NOT NULL default '',
  address varchar(255) default NULL,
  ticket varchar(255) default NULL,
  point varchar(255) default NULL
) TYPE=MyISAM;

--
-- Table structure for table 'tlds'
--

CREATE TABLE tlds (
  TLDid int(10) unsigned NOT NULL auto_increment,
  TLD varchar(12) NOT NULL default '',
  orderid int(11) NOT NULL default '10',
  PRIMARY KEY  (TLDid)
) TYPE=MyISAM;

--
-- Table structure for table 'urlredirect'
--

CREATE TABLE urlredirect (
  urid int(10) unsigned NOT NULL auto_increment,
  ownerid int(10) unsigned NOT NULL default '0',
  url varchar(255) NOT NULL default '',
  secure tinyint(1) NOT NULL default '0',
  forwardto varchar(255) NOT NULL default '',
  page varchar(255) default NULL,
  cloak tinyint(1) NOT NULL default '0',
  title varchar(255) default NULL,
  keywords varchar(255) default NULL,
  description varchar(255) default NULL,
  PRIMARY KEY  (urid)
) TYPE=MyISAM;

