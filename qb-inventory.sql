CREATE TABLE IF NOT EXISTS `inventories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(255) NOT NULL,
  `items` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`items`)),
  PRIMARY KEY (`identifier`),
  KEY `id` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 1) Drop clusters (stash centroid)
CREATE TABLE IF NOT EXISTS `inventory_drop_clusters` (
  `cluster_id` VARCHAR(32) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`cluster_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2) Item stacks (each prop in a cluster)
CREATE TABLE IF NOT EXISTS `inventory_drop_stacks` (
  `stack_id`   VARCHAR(32) NOT NULL,
  `cluster_id` VARCHAR(32) NOT NULL,
  `item_name`  VARCHAR(64) NOT NULL,
  `amount`     INT NOT NULL DEFAULT 1,
  `item_type`  VARCHAR(32) NOT NULL,
  `info_json`      LONGTEXT NULL,
  `metadata_json`  LONGTEXT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `model` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`stack_id`),
  KEY `idx_cluster_id` (`cluster_id`),
  CONSTRAINT `fk_drop_cluster` FOREIGN KEY (`cluster_id`)
    REFERENCES `inventory_drop_clusters` (`cluster_id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
