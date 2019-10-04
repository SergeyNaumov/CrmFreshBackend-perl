-- MySQL dump 10.13  Distrib 5.7.22, for Linux (x86_64)
--
-- Host: localhost    Database: crm
-- ------------------------------------------------------
-- Server version	5.7.22-0ubuntu0.16.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `crm_const`
--

DROP TABLE IF EXISTS `crm_const`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `crm_const` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '',
  `value` varchar(512) NOT NULL DEFAULT '',
  `field_value` text NOT NULL,
  `header` varchar(200) NOT NULL DEFAULT '',
  `comment` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `crm_const`
--

LOCK TABLES `crm_const` WRITE;
/*!40000 ALTER TABLE `crm_const` DISABLE KEYS */;
/*!40000 ALTER TABLE `crm_const` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `crm_save_filters`
--

DROP TABLE IF EXISTS `crm_save_filters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `crm_save_filters` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `manager_id` int(10) unsigned DEFAULT NULL,
  `header` varchar(255) NOT NULL DEFAULT '',
  `config` varchar(50) NOT NULL DEFAULT '',
  `json` text,
  `registered` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `manager_id` (`manager_id`),
  CONSTRAINT `crm_save_filters_ibfk_1` FOREIGN KEY (`manager_id`) REFERENCES `manager` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Сохранение фильтрров в CRM';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `crm_save_filters`
--

LOCK TABLES `crm_save_filters` WRITE;
/*!40000 ALTER TABLE `crm_save_filters` DISABLE KEYS */;
/*!40000 ALTER TABLE `crm_save_filters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `manager`
--

DROP TABLE IF EXISTS `manager`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `manager` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `login` varchar(50) NOT NULL DEFAULT '',
  `password` varchar(20) NOT NULL DEFAULT '',
  `name` varchar(100) NOT NULL DEFAULT '',
  `email` varchar(100) NOT NULL DEFAULT '',
  `group_id` int(10) unsigned DEFAULT NULL,
  `login_tel` varchar(50) NOT NULL DEFAULT '',
  `re_id` int(10) unsigned NOT NULL DEFAULT '0',
  `gone` tinyint(1) NOT NULL DEFAULT '0',
  `gone_date` date DEFAULT NULL,
  `phone` varchar(30) NOT NULL DEFAULT '',
  `current_role` int(10) unsigned NOT NULL DEFAULT '0',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  `mobile_phone` varchar(30) NOT NULL DEFAULT '',
  `photo` varchar(20) NOT NULL DEFAULT '',
  `phone_dob` varchar(20) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `login` (`login`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `manager`
--

LOCK TABLES `manager` WRITE;
/*!40000 ALTER TABLE `manager` DISABLE KEYS */;
INSERT INTO `manager` VALUES (1,'admin','admin','','',NULL,'',0,0,NULL,'',0,1,'','','');
/*!40000 ALTER TABLE `manager` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `manager_group`
--

DROP TABLE IF EXISTS `manager_group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `manager_group` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) DEFAULT NULL,
  `path` varchar(20) NOT NULL DEFAULT '',
  `header` varchar(50) NOT NULL DEFAULT '',
  `owner_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `manager_group`
--

LOCK TABLES `manager_group` WRITE;
/*!40000 ALTER TABLE `manager_group` DISABLE KEYS */;
INSERT INTO `manager_group` VALUES (1,NULL,'','Группа продаж',0),(2,NULL,'','Отдел маркетинга',0);
/*!40000 ALTER TABLE `manager_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `manager_group_permissions`
--

DROP TABLE IF EXISTS `manager_group_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `manager_group_permissions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `group_id` int(10) unsigned NOT NULL,
  `permissions_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `group_id` (`group_id`),
  KEY `permissions_id` (`permissions_id`),
  CONSTRAINT `manager_group_permissions_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `manager_group` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `manager_group_permissions_ibfk_2` FOREIGN KEY (`permissions_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `manager_group_permissions`
--

LOCK TABLES `manager_group_permissions` WRITE;
/*!40000 ALTER TABLE `manager_group_permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `manager_group_permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `manager_permissions`
--

DROP TABLE IF EXISTS `manager_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `manager_permissions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `manager_id` int(10) unsigned NOT NULL,
  `permissions_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `manager_id` (`manager_id`),
  KEY `permissions_id` (`permissions_id`),
  CONSTRAINT `manager_permissions_ibfk_1` FOREIGN KEY (`manager_id`) REFERENCES `manager` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `manager_permissions_ibfk_2` FOREIGN KEY (`permissions_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2102 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `manager_permissions`
--

LOCK TABLES `manager_permissions` WRITE;
/*!40000 ALTER TABLE `manager_permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `manager_permissions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `permissions`
--

DROP TABLE IF EXISTS `permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `permissions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `sort` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `header` varchar(100) NOT NULL DEFAULT '',
  `pname` varchar(50) NOT NULL DEFAULT '',
  `path` varchar(20) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `pname` (`pname`),
  KEY `parent_id` (`parent_id`),
  CONSTRAINT `permissions_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `permissions`
--

LOCK TABLES `permissions` WRITE;
/*!40000 ALTER TABLE `permissions` DISABLE KEYS */;
/*!40000 ALTER TABLE `permissions` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2018-04-27 17:02:08
create table session(
    id int unsigned primary key auto_increment,
    auth_id int unsigned not null,
    registered timestamp not null,
    session_key varchar(255) not null default '',
    constraint foreign key(auth_id) references manager(id) on update cascade on delete cascade
) engine=innodb default charset=utf8;

create table session_fails(
    id int unsigned primary key auto_increment,
    login varchar(20) not null default '',
    ip  varchar(20) not null default '',
    registered timestamp not null,
    key(login,registered),
    key(ip,registered)
) engine=innodb default charset utf8;

CREATE TABLE `manager_menu` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `sort` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `header` varchar(100) NOT NULL DEFAULT '',
  `permission_id` int(10) unsigned DEFAULT NULL,
  `path` varchar(20) NOT NULL DEFAULT '',
  `url` varchar(200) NOT NULL DEFAULT '',
  `target` varchar(20) DEFAULT NULL,
  `params` varchar(512) NOT NULL DEFAULT '',
  `icon` varchar(50) NOT NULL DEFAULT '',
  `value` varchar(512) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `parent_id` (`parent_id`),
  CONSTRAINT `manager_menu_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `manager_menu` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=66 DEFAULT CHARSET=utf8;