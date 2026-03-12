package org.avni.server.util;

import org.junit.Test;
import org.slf4j.Logger;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class WebResponseUtilTest {
    @Test
    public void testGenerateJsonError() {
        Map<String, String> result = WebResponseUtil.generateJsonError("error");
        assertEquals("error", result.get("message"));
    }
    
    @Test
    public void testCreateBadRequestResponse() {
        Logger logger = mock(Logger.class);
        Exception e = new Exception("bad request");
        ResponseEntity<Map<String, String>> response = WebResponseUtil.createBadRequestResponse(e, logger);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals("bad request", response.getBody().get("message"));
    }
}
