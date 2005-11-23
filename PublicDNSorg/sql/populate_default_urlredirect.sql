--
-- Add a default entry for the urlredirect.
-- NOTE: update the 'forwardto' to your site hostname
--
INSERT INTO urlredirect (urid, ownerid, url, secure, forwardto, page, cloak, title, keywords, description) VALUES (1, 1, 'default', 0, '127.0.0.1','/index.html?section=urlforwarding', 0, NULL, NULL, NULL);
