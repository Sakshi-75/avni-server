package org.avni.server.domain;

import org.avni.server.web.request.rules.response.RuleError;
import org.junit.Test;
import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class RuleExecutionExceptionTest {
    @Test
    public void testExceptionWithRuleError() {
        RuleError ruleError = mock(RuleError.class);
        RuleExecutionException exception = new RuleExecutionException(ruleError);
        
        assertNotNull(exception.getRuleError());
        assertEquals(ruleError, exception.getRuleError());
    }
    
    @Test
    public void testExceptionIsCheckedException() {
        RuleError ruleError = mock(RuleError.class);
        RuleExecutionException exception = new RuleExecutionException(ruleError);
        
        assertTrue(exception instanceof Exception);
    }
}
