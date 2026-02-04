import logging


def setup_logging(service_name: str, level: int = logging.INFO) -> logging.Logger:
    """
    Set up logging configuration for a service.
    
    Args:
        service_name: Name of the service (e.g., 'service_a', 'service_b')
        level: Logging level (default: INFO)
    
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(service_name)
    logger.setLevel(level)
    
    # Avoid adding multiple handlers if already configured
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setLevel(level)
        
        formatter = logging.Formatter(
            '%(asctime)s %(levelname)s %(name)s %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    
    return logger
