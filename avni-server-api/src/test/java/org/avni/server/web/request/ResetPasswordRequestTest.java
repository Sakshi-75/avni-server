package org.avni.server.web.request;

import org.junit.Test;
import static org.junit.Assert.*;

public class ResetPasswordRequestTest {
    @Test
    public void testGettersAndSetters() {
        ResetPasswordRequest request = new ResetPasswordRequest();
        assertEquals(0, request.getUserId());
        assertNull(request.getPassword());
        
        request.setUserId(123L);
        request.setPassword("resetPass456");
        
        assertEquals(123L, request.getUserId());
        assertEquals("resetPass456", request.getPassword());
    }
}
