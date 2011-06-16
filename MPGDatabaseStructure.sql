-- MySQL dump 10.13  Distrib 5.5.13, for Linux (i686)
--
-- Host: 192.168.99.195    Database: Comway
-- ------------------------------------------------------
-- Server version	5.1.41-3ubuntu12.10

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
-- Table structure for table `Config`
--

DROP TABLE IF EXISTS `Config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Config` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `SMTP` varchar(100) NOT NULL,
  `EAUTHID` varchar(100) NOT NULL,
  `EAUTHPASS` varchar(100) NOT NULL,
  `Status` enum('Enabled','Disabled') NOT NULL,
  `Frequency` int(11) NOT NULL DEFAULT '3',
  PRIMARY KEY (`Id`)
) ENGINE=MyISAM AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Email_ATTACHMENTS`
--

DROP TABLE IF EXISTS `Email_ATTACHMENTS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Email_ATTACHMENTS` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Path` varchar(250) NOT NULL,
  `Header` bigint(20) NOT NULL,
  `AttDate` date NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `Header` (`Header`),
  CONSTRAINT `Header` FOREIGN KEY (`Header`) REFERENCES `Email_OUT` (`Id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5864 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Email_OUT`
--

DROP TABLE IF EXISTS `Email_OUT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Email_OUT` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `From` varchar(50) CHARACTER SET latin1 NOT NULL,
  `Subject` varchar(250) CHARACTER SET latin1 NOT NULL,
  `To` varchar(250) CHARACTER SET latin1 NOT NULL,
  `Cc` varchar(250) CHARACTER SET latin1 NOT NULL,
  `Bcc` varchar(250) CHARACTER SET latin1 NOT NULL,
  `Priority` enum('1','2','3','4','5') CHARACTER SET latin1 NOT NULL DEFAULT '3',
  `Body` text CHARACTER SET latin1 NOT NULL,
  `Date` date NOT NULL,
  `Retry` int(11) NOT NULL,
  `Status` char(250) CHARACTER SET latin1 NOT NULL,
  `Mount` enum('Y','N') CHARACTER SET latin1 NOT NULL DEFAULT 'N',
  `ClusterId` varchar(10) NOT NULL,
  `Time` time NOT NULL,
  `Sent` enum('Y','N') NOT NULL DEFAULT 'N',
  `Zip` enum('Y','N') NOT NULL DEFAULT 'N',
  `Created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `Replyto` varchar(259) NOT NULL,
  `Class` varchar(250) NOT NULL DEFAULT 'NONE',
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=6213 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TwitterAction`
--

DROP TABLE IF EXISTS `TwitterAction`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TwitterAction` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Type` enum('SQL','SUB') NOT NULL,
  `SQL_Host` varchar(50) NOT NULL,
  `SQL_Table` varchar(50) NOT NULL,
  `SQL_User` varchar(50) NOT NULL,
  `SQL_Pass` varchar(50) NOT NULL,
  `SQL_Query` longtext NOT NULL,
  `SQL_Answer` longtext NOT NULL,
  `Status` enum('Enabled','Disabled') NOT NULL,
  `Trigger` varchar(50) NOT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TwitterConfig`
--

DROP TABLE IF EXISTS `TwitterConfig`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TwitterConfig` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ACCOUNT` varchar(100) NOT NULL,
  `PASSWORD` varchar(100) NOT NULL,
  `Frequency` int(3) NOT NULL,
  `LastID` varchar(250) NOT NULL,
  `Status` enum('Enabled','Disabled') NOT NULL,
  `consumer_key` varchar(100) NOT NULL,
  `consumer_secret` varchar(100) NOT NULL,
  `access_token` varchar(100) NOT NULL,
  `access_token_secret` varchar(100) NOT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TwitterMessages`
--

DROP TABLE IF EXISTS `TwitterMessages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TwitterMessages` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `From` varchar(100) NOT NULL,
  `TimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Message` varchar(250) NOT NULL,
  `Dump` mediumtext NOT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=MyISAM AUTO_INCREMENT=57 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-06-16 16:39:10
